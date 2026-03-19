# Efficient Tool Usage Rules

## 1. File Editing Strategy
- **ALWAYS read a file before editing it.** Never call `power---file_edit` without first calling `power---file_read` on that file in the same session.
- **Prefer `power---file_write` with mode `overwrite` for new files** or when replacing most of a file's content. Do NOT build files incrementally via multiple `append` calls — write the complete file in one call.
- **Use `power---file_edit` only for surgical changes** to existing files where you are modifying a small section. If changing more than 30% of the file, use `power---file_write` with `overwrite` instead.
- **Never shell out to Python, sed, or Ruby one-liners to edit files.** Use the provided `power---file_edit` or `power---file_write` tools exclusively. If `file_edit` fails with "Search term not found", use `power---file_read` to get the current content, then `power---file_write` with `overwrite` to replace the entire file.
- **Never debug encoding issues.** Do not run `hexdump`, `cat -A`, `od`, or similar encoding diagnostics on files. If `file_edit` fails, just read the file and overwrite it.

## 2. Limit Exploration — Act Early
- **Read at most 3-5 files before your first write.** Your task prompt tells you what to build. Read only the files directly relevant to your task (the target file, its test file, and 1-2 dependency files).
- **Do NOT explore the entire codebase.** Skip `glob` and `grep` surveys unless you genuinely don't know where a file lives. If the task prompt names specific files, go directly to them.
- **Write first, iterate second.** Produce your best attempt quickly, then run tests and fix failures. This is faster than reading 15 files trying to write perfect code on the first attempt.
- **If reference files are pre-loaded in your prompt**, do NOT re-read them. Use the content already provided.

## 3. Test Execution
- **Run tests early and often.** After writing code or tests, run them immediately. Don't wait until everything looks perfect.
- **Run only the relevant test file first** (e.g., `bundle exec rspec spec/lib/my_class_spec.rb`), not the entire suite. Run the full suite only as a final verification.
- **Each red-green cycle should be 1-3 turns**, not 10+. Write → run → fix → run.

## 4. Task Completion — Stop When Done
- **When all tests pass, STOP.** Do not continue reading files, verifying, or exploring after tests are green.
- **Do not test if tools work.** Never run diagnostic commands like `echo "test" > /tmp/test.txt` or `pwd`. The tools work. Use them for your actual task.
- **After the full test suite passes, your only remaining step is a brief summary.** Do not start additional verification loops.
