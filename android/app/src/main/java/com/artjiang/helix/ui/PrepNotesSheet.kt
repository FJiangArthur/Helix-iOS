package com.artjiang.helix.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.artjiang.helix.HelixBridge
import com.artjiang.helix.conversate.PrepNote
import com.artjiang.helix.conversate.PrepNoteRepository

/** List + editor for Prep Notes (text, or imported from a .txt file). */
@Composable
fun PrepNotesSheet(bridge: HelixBridge, onDismiss: () -> Unit) {
    val notes by bridge.prepNoteRepository.notes.collectAsStateWithLifecycle()
    var editing by remember { mutableStateOf<PrepNote?>(null) }
    val context = LocalContext.current
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = runCatching {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        }.getOrNull().orEmpty()
        val name = uri.lastPathSegment?.substringAfterLast('/')?.substringBeforeLast('.') ?: "Imported"
        editing = PrepNoteRepository.new(name, text, System.currentTimeMillis())
    }

    val current = editing
    if (current != null) {
        var title by remember(current.id) { mutableStateOf(current.title) }
        var text by remember(current.id) { mutableStateOf(current.text) }
        AlertDialog(
            onDismissRequest = { editing = null },
            title = { Text("Prep note") },
            text = {
                Column {
                    OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true)
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it.take(PrepNoteRepository.MAX_CHARS) },
                        label = { Text("Context (${text.length}/${PrepNoteRepository.MAX_CHARS})") },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    bridge.upsertPrepNote(current.copy(title = title.ifBlank { "Untitled" }, text = text, updatedAtMillis = System.currentTimeMillis()))
                    editing = null
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { editing = null }) { Text("Cancel") } },
        )
        return
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Prep notes") },
        text = {
            Column {
                if (notes.isEmpty()) Text("No prep notes yet.")
                notes.forEach { n ->
                    Row {
                        TextButton(onClick = { editing = n }, modifier = Modifier.weight(1f)) { Text(n.title) }
                        TextButton(onClick = { bridge.deletePrepNote(n.id) }) { Text("Delete") }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { editing = PrepNoteRepository.new("", "", System.currentTimeMillis()) }) { Text("New") }
        },
        dismissButton = {
            Row {
                TextButton(onClick = { importer.launch(arrayOf("text/plain")) }) { Text("Import .txt") }
                TextButton(onClick = onDismiss) { Text("Done") }
            }
        },
    )
}
