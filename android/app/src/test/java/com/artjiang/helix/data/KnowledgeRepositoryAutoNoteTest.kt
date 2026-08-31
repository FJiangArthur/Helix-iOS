package com.artjiang.helix.data

import com.artjiang.helix.AutomaticNoteReceipt
import com.artjiang.helix.AutomaticNoteSavedItem
import com.artjiang.helix.core.KnowledgeBucket
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class KnowledgeRepositoryAutoNoteTest {

    @get:Rule
    val tmp = TemporaryFolder()

    @Test
    fun `automatic note insert is persistent deduped and removable`() = runBlocking {
        val file = File(tmp.root, "knowledge.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val first = repository.addIfAbsent(
                bucket = KnowledgeBucket.TODOS,
                text = "Send the release notes Friday.",
                source = "Helix auto-note · Action item",
            )
            val duplicate = repository.addIfAbsent(
                bucket = KnowledgeBucket.TODOS,
                text = "  send the release notes friday  ",
                source = "Helix auto-note · Action item",
            )

            assertNotNull(first)
            assertNull("case, whitespace and trailing punctuation do not create duplicate notes", duplicate)
            assertEquals(1, repository.loaded().size)

            repository.remove(first!!.id)
            assertEquals(emptyList<com.artjiang.helix.core.KnowledgeItem>(), repository.loaded())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `merged multi-question receipt undo removes every newly saved note`() = runBlocking {
        val file = File(tmp.root, "knowledge-multi.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val first = repository.addIfAbsent(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: Retrieval-augmented generation.",
                "Helix auto-note · Answer",
            )!!
            val second = repository.addIfAbsent(
                KnowledgeBucket.FACTS,
                "Q: How does it help?\nA: It grounds the answer.",
                "Helix auto-note · Answer",
            )!!
            val receipt = AutomaticNoteReceipt(
                listOf(AutomaticNoteSavedItem(first.id, first.bucket, first.text)),
            ).mergedWith(
                listOf(AutomaticNoteSavedItem(second.id, second.bucket, second.text)),
            )

            receipt.itemIds.forEach { repository.remove(it) }

            assertEquals(emptyList<com.artjiang.helix.core.KnowledgeItem>(), repository.loaded())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `automatic answers update one question identity across provider paraphrases`() = runBlocking {
        val file = File(tmp.root, "knowledge-question-dedupe.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val first = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: What is the capital of France?\nA: Paris is the capital of France.",
                AutomaticAnswerQuality.FAST,
            )
            val correction = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Question: what is the capital of France？\n\nAnswer: France's capital city is Paris.",
                AutomaticAnswerQuality.FAST,
            )
            val quotedCorrection = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital.",
                AutomaticAnswerQuality.SMART,
            )
            val exactRepeat = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "  Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital.  ",
                AutomaticAnswerQuality.SMART,
            )

            assertNotNull(first)
            assertNotNull("a changed answer should update the automatic fact in place", correction)
            assertEquals(first!!.item.id, correction!!.item.id)
            assertEquals(first.item, correction.previousItem)
            assertNotNull("a closing quote must not create a second question identity", quotedCorrection)
            assertEquals(first.item.id, quotedCorrection!!.item.id)
            assertEquals(correction.item, quotedCorrection.previousItem)
            assertNull("an exact normalized repeat is a no-op", exactRepeat)
            val stored = repository.loaded()
            assertEquals(1, stored.size)
            assertEquals(
                "Question: “What is the capital of France?”\n\nAnswer: Paris remains France's capital.",
                stored.single().text,
            )
            assertEquals(
                KnowledgeRepository.automaticAnswerSource(AutomaticAnswerQuality.SMART),
                stored.single().source,
            )
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `automatic answer dedupe never removes preexisting manual memories`() = runBlocking {
        val file = File(tmp.root, "knowledge-manual-preservation.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            repository.add(
                KnowledgeBucket.FACTS,
                "Q: What is the capital of France?\nA: A manually saved concise answer.",
                "Manual",
            )
            repository.add(
                KnowledgeBucket.FACTS,
                "Question: what is the capital of France？\n\nAnswer: A second manual research note.",
                "Manual",
            )
            val manualBefore = repository.loaded()

            val automatic = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: WHAT IS THE CAPITAL OF FRANCE\nA: A later automatic paraphrase.",
                AutomaticAnswerQuality.FAST,
            )

            assertNotNull("manual Q+A must not suppress an automatic answer", automatic)
            val stored = repository.loaded()
            assertEquals("automatic capture must preserve both manual notes", 3, stored.size)
            assertEquals(
                "manual ids, text, source, and timestamps must remain byte-for-byte unchanged",
                manualBefore,
                stored.filter { it.source == "Manual" },
            )
            assertEquals(1, stored.count { KnowledgeRepository.isAutomaticAnswerSource(it.source) })
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `smart answer supersedes fast reversibly and fast cannot downgrade it`() = runBlocking {
        val file = File(tmp.root, "knowledge-smart-upgrade.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val fast = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: Why is the sky blue?\nA: Air scatters blue light.",
                AutomaticAnswerQuality.FAST,
            )!!
            val smart = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: Why is the sky blue?\nA: Rayleigh scattering favors shorter visible wavelengths.",
                AutomaticAnswerQuality.SMART,
            )!!
            val smartCorrection = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: Why is the sky blue?\nA: Rayleigh scattering strongly favors shorter visible wavelengths.",
                AutomaticAnswerQuality.SMART,
            )!!
            val downgrade = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: Why is the sky blue?\nA: A later fast paraphrase.",
                AutomaticAnswerQuality.FAST,
            )

            assertEquals(fast.item.id, smart.item.id)
            assertEquals(fast.item, smart.previousItem)
            assertEquals(smart.item.id, smartCorrection.item.id)
            assertEquals(smart.item, smartCorrection.previousItem)
            assertNull("FAST must not replace an existing SMART answer", downgrade)
            assertEquals(smartCorrection.item, repository.loaded().single())

            val exactRepeat = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "  Q: Why is the sky blue?\nA: Rayleigh scattering strongly favors shorter visible wavelengths.  ",
                AutomaticAnswerQuality.SMART,
            )
            assertNull(exactRepeat)
            assertEquals(
                "an exact repeat must not mutate source, identity, or timestamp",
                smartCorrection.item,
                repository.loaded().single(),
            )

            repository.undoAutomaticAnswer(smartCorrection.item.id, smartCorrection.previousItem)
            assertEquals(smart.item, repository.loaded().single())
            repository.undoAutomaticAnswer(smart.item.id, smart.previousItem)
            assertEquals(fast.item, repository.loaded().single())
            repository.undoAutomaticAnswer(fast.item.id, fast.previousItem)
            assertEquals(emptyList<com.artjiang.helix.core.KnowledgeItem>(), repository.loaded())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `identical smart answer upgrades fast provenance and blocks later fast correction`() = runBlocking {
        val file = File(tmp.root, "knowledge-identical-smart-upgrade.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val text = "Q: What is RAG?\nA: Retrieval-augmented generation grounds answers."
            val fast = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                text,
                AutomaticAnswerQuality.FAST,
            )!!
            val smart = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                text,
                AutomaticAnswerQuality.SMART,
            )!!
            val laterFast = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: A later FAST correction must not replace SMART provenance.",
                AutomaticAnswerQuality.FAST,
            )

            assertEquals(fast.item.id, smart.item.id)
            assertEquals(fast.item, smart.previousItem)
            assertEquals(text, smart.item.text)
            assertEquals(
                KnowledgeRepository.automaticAnswerSource(AutomaticAnswerQuality.SMART),
                smart.item.source,
            )
            assertNull(laterFast)
            assertEquals(smart.item, repository.loaded().single())

            repository.undoAutomaticAnswer(smart.item.id, smart.previousItem)
            assertEquals(fast.item, repository.loaded().single())
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `automatic upsert never cleans up legacy automatic rows`() = runBlocking {
        val file = File(tmp.root, "knowledge-legacy-preservation.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            repository.add(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: Legacy answer one.",
                KnowledgeRepository.AUTOMATIC_ANSWER_SOURCE_PREFIX,
            )
            repository.add(
                KnowledgeBucket.FACTS,
                "Question: What is RAG?\nAnswer: Legacy answer two.",
                KnowledgeRepository.AUTOMATIC_ANSWER_SOURCE_PREFIX,
            )
            val before = repository.loaded()

            val update = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: A current SMART answer.",
                AutomaticAnswerQuality.SMART,
            )!!
            val after = repository.loaded()

            assertEquals("no legacy row is deleted as a side effect", before.size, after.size)
            assertEquals(before.map { it.id }.toSet(), after.map { it.id }.toSet())
            assertEquals(before.first(), update.previousItem)
            assertEquals(
                "the unrelated legacy duplicate remains untouched",
                before[1],
                after.first { it.id == before[1].id },
            )
        } finally {
            scope.cancel()
        }
    }

    @Test
    fun `merged insert then smart update undo removes the newly created item`() = runBlocking {
        val file = File(tmp.root, "knowledge-merged-undo.json")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        try {
            val repository = KnowledgeRepository(file, scope)
            val fast = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: Fast answer.",
                AutomaticAnswerQuality.FAST,
            )!!
            val firstReceipt = AutomaticNoteReceipt(
                listOf(
                    AutomaticNoteSavedItem(
                        fast.item.id,
                        fast.item.bucket,
                        fast.item.text,
                        fast.previousItem,
                    ),
                ),
            )
            val smart = repository.upsertAutomaticAnswer(
                KnowledgeBucket.FACTS,
                "Q: What is RAG?\nA: Deeper SMART answer.",
                AutomaticAnswerQuality.SMART,
            )!!
            val merged = firstReceipt.mergedWith(
                listOf(
                    AutomaticNoteSavedItem(
                        smart.item.id,
                        smart.item.bucket,
                        smart.item.text,
                        smart.previousItem,
                    ),
                ),
            )

            assertNull("the earliest receipt remembers that this id was newly inserted", merged.items.single().previousItem)
            merged.items.asReversed().forEach {
                repository.undoAutomaticAnswer(it.id, it.previousItem)
            }
            assertEquals(emptyList<com.artjiang.helix.core.KnowledgeItem>(), repository.loaded())
        } finally {
            scope.cancel()
        }
    }
}
