#!/usr/bin/env bash
# concat_rag_structure.sh
# Run this from the project root: ./concat_rag_structure.sh
# Output: rag-structure-full.txt in current directory

set -euo pipefail

OUTPUT_FILE="rag-structure-full.txt"
RAG_DIR="knowledge_base/agentic-planning/rag-structure"

if [[ ! -d "$RAG_DIR" ]]; then
echo "Error: Directory $RAG_DIR not found. Run from project root."
exit 1
fi

> "$OUTPUT_FILE"  # Clear/overwrite output

echo "# Full Concatenated Contents of rag-structure/" >> "$OUTPUT_FILE"
echo "# Generated on $(date)" >> "$OUTPUT_FILE"
echo "# --------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Find all files recursively, sort for consistent order
find "$RAG_DIR" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.txt" \) \
  | sort \
  | while read -r file; do
  rel_path="${file#"$RAG_DIR"/}"  # relative path
  echo "## FILE: $rel_path" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo '```' >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  done

  echo "Done. Output written to $OUTPUT_FILE"
  echo "Size: $(du -h "$OUTPUT_FILE" | cut -f1)"