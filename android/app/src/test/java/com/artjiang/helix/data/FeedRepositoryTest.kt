package com.artjiang.helix.data

import com.artjiang.helix.FeedEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * The Assistant feed must survive a process restart — before persistence it was
 * a bare MutableStateFlow, so every relaunch lost the whole conversation.
 */
class FeedRepositoryTest {

    @get:Rule
    val tmp = TemporaryFolder()

    // The File constructor, not the Context one: this module has no
    // Robolectric, so a real Context cannot be built on the JVM.
    private fun <T> withRepo(file: File, limit: Int = 200, block: suspend (FeedRepository) -> T): T =
        runBlocking {
            val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
            try {
                block(FeedRepository(file, scope, limit = limit))
            } finally {
                scope.cancel()
            }
        }

    private fun entry(id: Long, text: String, kind: FeedEntry.Kind = FeedEntry.Kind.TRANSCRIPT) =
        FeedEntry(id = id, kind = kind, text = text, atMillis = id * 1_000)

    @Test
    fun `appended entries survive a fresh repository over the same file`() {
        val file = File(tmp.root, "feed.json")
        withRepo(file) { repo ->
            repo.append(entry(1, "hello"))
            repo.append(entry(2, "is this on?", FeedEntry.Kind.QUESTION))
        }
        // A new repository is what a process restart produces.
        withRepo(file) { repo ->
            val restored = repo.loaded()
            assertEquals(listOf(1L, 2L), restored.map { it.id })
            assertEquals("is this on?", restored[1].text)
            assertEquals(FeedEntry.Kind.QUESTION, restored[1].kind)
        }
    }

    @Test
    fun `answer metadata round-trips`() {
        val file = File(tmp.root, "feed.json")
        val answer = FeedEntry(
            id = 7,
            kind = FeedEntry.Kind.ANSWER,
            text = "42",
            model = "gpt-4.1",
            question = "what is the answer",
            atMillis = 1_234,
        )
        withRepo(file) { it.append(answer) }
        withRepo(file) { repo -> assertEquals(listOf(answer), repo.loaded()) }
    }

    @Test
    fun `the limit is applied to what reaches disk, not just memory`() {
        val file = File(tmp.root, "feed.json")
        withRepo(file, limit = 3) { repo ->
            (1..10).forEach { repo.append(entry(it.toLong(), "line $it")) }
            assertEquals(listOf(8L, 9L, 10L), repo.entries.value.map { it.id })
        }
        withRepo(file, limit = 3) { repo ->
            // The file itself must be capped; a growing file would reload
            // everything and defeat the cap.
            assertEquals(listOf(8L, 9L, 10L), repo.loaded().map { it.id })
        }
    }

    @Test
    fun `clear starts a fresh conversation and persists the emptiness`() {
        val file = File(tmp.root, "feed.json")
        withRepo(file) { repo ->
            repo.append(entry(1, "old talk"))
            repo.clear()
            assertTrue(repo.entries.value.isEmpty())
        }
        withRepo(file) { repo -> assertTrue(repo.loaded().isEmpty()) }
    }

    @Test
    fun `a feed file written before speaker attribution existed still loads`() {
        // Exactly the shape FeedEntry serialized to before `speaker`/`isUser`
        // were added — no such keys present at all. A user upgrading with an
        // existing helix_feed.json must not lose their conversation or crash.
        val file = File(tmp.root, "feed.json")
        file.writeText(
            """
            [{"id":1,"kind":"TRANSCRIPT","text":"hello","atMillis":1000}]
            """.trimIndent(),
        )
        withRepo(file) { repo ->
            val restored = repo.loaded()
            assertEquals(1, restored.size)
            assertEquals("hello", restored[0].text)
            assertEquals(null, restored[0].speaker)
            assertEquals(false, restored[0].isUser)
        }
    }

    @Test
    fun `matching finalized transcript is promoted to question without losing speaker`() {
        val file = File(tmp.root, "feed.json")
        withRepo(file) { repo ->
            repo.append(
                FeedEntry(
                    id = 11,
                    kind = FeedEntry.Kind.TRANSCRIPT,
                    text = "What is the capital of France?",
                    atMillis = 1_000,
                    speaker = "SPEAKER_02",
                    isUser = false,
                ),
            )

            assertTrue(repo.promoteMatchingTranscriptToQuestion(11, "What is the capital of France?"))
            val rows = repo.loaded()
            assertEquals(1, rows.size)
            assertEquals(FeedEntry.Kind.QUESTION, rows.single().kind)
            assertEquals("SPEAKER_02", rows.single().speaker)
            assertEquals(false, rows.single().isUser)
        }
    }

    @Test
    fun `distinct transcript context is not promoted to a different detected question`() {
        val file = File(tmp.root, "feed.json")
        withRepo(file) { repo ->
            repo.append(entry(12, "Context first. What changed?"))

            assertEquals(false, repo.promoteMatchingTranscriptToQuestion(12, "What changed?"))
            assertEquals(FeedEntry.Kind.TRANSCRIPT, repo.loaded().single().kind)
        }
    }
}
