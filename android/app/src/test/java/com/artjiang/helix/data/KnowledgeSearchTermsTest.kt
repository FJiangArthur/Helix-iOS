package com.artjiang.helix.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for the Unicode-aware search tokenizer. The previous
 * ASCII-only `\W+` split reduced every CJK query to zero terms, so knowledge
 * retrieval silently never ran for Chinese — a supported input.
 */
class KnowledgeSearchTermsTest {

    @Test
    fun `chinese query produces bigram terms`() {
        val terms = KnowledgeRepository.searchTerms("什么是量子计算")
        assertTrue("CJK query must produce terms", terms.isNotEmpty())
        assertTrue("bigrams cover the query", terms.contains("量子"))
        assertTrue(terms.contains("计算"))
    }

    @Test
    fun `chinese query with punctuation still tokenizes`() {
        val terms = KnowledgeRepository.searchTerms("什么是量子计算？")
        assertTrue(terms.isNotEmpty())
    }

    @Test
    fun `short english names survive the noise filter`() {
        val terms = KnowledgeRepository.searchTerms("who is Bob?")
        assertTrue("3-char terms are kept", terms.contains("who"))
        assertTrue(terms.contains("bob"))
    }

    @Test
    fun `two character english noise is dropped`() {
        val terms = KnowledgeRepository.searchTerms("is it on at")
        assertEquals(emptyList<String>(), terms)
    }

    @Test
    fun `mixed script query keeps both kinds of terms`() {
        val terms = KnowledgeRepository.searchTerms("explain 量子 computing")
        assertTrue(terms.contains("explain"))
        assertTrue(terms.contains("computing"))
        assertTrue(terms.contains("量子"))
    }
}
