#!/usr/bin/env python3
"""
Quick script to remind users to update AI context after significant changes.

Usage:
    python AI/update_context.py check    # Check if update needed
    python AI/update_context.py prompt   # Show update prompt for AI
"""

import sys
from pathlib import Path
from datetime import datetime
import yaml

CONTEXT_FILE = Path(__file__).parent / "ai_context.yaml"
MAX_AGE_DAYS = 7  # Warn if context is older than this


def load_context():
    """Load the current AI context."""
    if not CONTEXT_FILE.exists():
        print(f"❌ Context file not found: {CONTEXT_FILE}")
        sys.exit(1)
    
    with open(CONTEXT_FILE, 'r') as f:
        return yaml.safe_load(f)


def check_age():
    """Check if context file needs updating based on age."""
    context = load_context()
    last_updated = context.get('last_updated')
    
    if not last_updated:
        print("⚠️  No 'last_updated' timestamp in ai_context.yaml")
        return True
    
    # Parse timestamp
    try:
        updated_date = datetime.fromisoformat(last_updated)
        age_days = (datetime.now() - updated_date).days
        
        if age_days > MAX_AGE_DAYS:
            print(f"⚠️  AI context is {age_days} days old (threshold: {MAX_AGE_DAYS} days)")
            print(f"   Last updated: {last_updated}")
            print("\n   Consider updating if you've made significant changes.")
            return True
        else:
            print(f"✅ AI context is current ({age_days} days old)")
            return False
            
    except Exception as e:
        print(f"⚠️  Could not parse last_updated timestamp: {e}")
        return True


def show_prompt():
    """Show the prompt to give to AI for context update."""
    context = load_context()
    
    print("=" * 70)
    print("AI CONTEXT UPDATE PROMPT")
    print("=" * 70)
    print("\nCopy this prompt to your AI assistant:\n")
    print("-" * 70)
    print("""
Review /opt/openproject/AI/ai_context.yaml and update these sections:

1. Update 'last_updated' to current timestamp
2. Update 'implementation_status' for components we worked on
3. Update 'immediate_todos' - remove completed, add new items
4. Update 'current_blockers' - resolve fixed ones, add new ones
5. Add entry to 'recent_changes' log with today's work

Summarize what changed: [describe your work here]
""")
    print("-" * 70)
    print("\nAfter AI updates, commit the changes:")
    print("  git add AI/ai_context.yaml")
    print("  git commit -m 'docs: update AI context - [brief description]'")
    print("=" * 70)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: python AI/update_context.py {check|prompt}")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "check":
        needs_update = check_age()
        sys.exit(0 if not needs_update else 1)
    elif command == "prompt":
        show_prompt()
    else:
        print(f"Unknown command: {command}")
        print("Usage: python AI/update_context.py {check|prompt}")
        sys.exit(1)


if __name__ == "__main__":
    main()
