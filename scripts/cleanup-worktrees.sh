#!/bin/bash
# Clean up Vibe Kanban worktrees and branches
# 
# This script removes all vibe-kanban-created git worktrees and their associated
# vk/* branches from the repository. Use this after Vibe Kanban automation tasks
# are complete and work has been merged.
#
# Usage: ./scripts/cleanup-worktrees.sh
# Safety: Prompts for confirmation before deletion (use -f for force)

set -e

FORCE=false
if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    FORCE=true
fi

echo "🧹 Ralph Git Cleanup Tool"
echo "=========================="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# List worktrees to remove
WORKTREES=$(git worktree list | grep vibe-kanban | awk '{print $1}')
BRANCHES=$(git branch | grep '^ *vk/' | awk '{print $1}')

if [ -z "$WORKTREES" ] && [ -z "$BRANCHES" ]; then
    echo "✅ No Vibe Kanban worktrees or vk/* branches found. Nothing to clean."
    exit 0
fi

echo "📋 Items to be removed:"
echo ""

if [ -n "$WORKTREES" ]; then
    echo "Worktrees:"
    git worktree list | grep vibe-kanban | while read line; do
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | awk '{print $2}' | sed 's/\[//;s/\]//')
        echo "  ❌ $path"
        echo "     Branch: $branch"
    done
    echo ""
fi

if [ -n "$BRANCHES" ]; then
    echo "Branches:"
    git branch | grep '^ *vk/' | while read branch; do
        echo "  ❌ $branch"
    done
    echo ""
fi

# Confirm deletion
if [ "$FORCE" = false ]; then
    read -p "⚠️  Proceed with cleanup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo ""
echo "🔧 Cleaning up..."
echo ""

# Remove worktrees
if [ -n "$WORKTREES" ]; then
    echo "Removing Vibe Kanban worktrees..."
    git worktree list | grep vibe-kanban | awk '{print $1}' | while read worktree; do
        echo "  ⏳ Removing: $worktree"
        git worktree remove "$worktree" 2>/dev/null || git worktree remove --force "$worktree" || true
        echo "  ✅ Removed"
    done
    echo ""
fi

# Remove branches
if [ -n "$BRANCHES" ]; then
    echo "Removing vk/* branches..."
    git branch | grep '^ *vk/' | awk '{print $1}' | while read branch; do
        echo "  ⏳ Deleting: $branch"
        git branch -D "$branch" || true
        echo "  ✅ Deleted"
    done
    echo ""
fi

echo "✨ Cleanup complete!"
echo ""
echo "📊 Remaining branches:"
git branch -a | head -20
echo ""
echo "📦 Remaining worktrees:"
git worktree list | head -5
