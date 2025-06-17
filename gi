#!/bin/bash

# GitHub Gitignore Fetcher Script
# Searches and appends gitignore templates from github/gitignore repository

set -e

GITHUB_API_BASE="https://api.github.com/repos/github/gitignore"
GITIGNORE_FILE=".gitignore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] <search_term>"
    echo ""
    echo "Options:"
    echo "  -l, --list              List all available gitignore templates"
    echo "  -s, --search <term>     Search for gitignore templates containing the term"
    echo "  -a, --append <file>     Append specific gitignore file to local .gitignore"
    echo "  -f, --file <path>       Specify custom .gitignore file path (default: ./.gitignore)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                    # List all available templates"
    echo "  $0 --search python           # Search for Python-related templates"
    echo "  $0 --append Python.gitignore # Append Python template to .gitignore"
    echo "  $0 python                   # Search for 'python' (shorthand)"
}

# Function to list all available gitignore templates
list_templates() {
    print_color $BLUE "Fetching available gitignore templates..."
    
    response=$(curl -s "$GITHUB_API_BASE/contents" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        print_color $RED "Error: Failed to fetch template list from GitHub API"
        exit 1
    fi
    
    # Check if response contains error
    if echo "$response" | grep -q '"message"'; then
        print_color $RED "Error: GitHub API returned an error"
        echo "$response" | grep '"message"' | sed 's/.*"message": *"\([^"]*\)".*/\1/'
        exit 1
    fi
    
    print_color $GREEN "Available gitignore templates:"
    
    # Try jq first for better JSON parsing
    templates=$(echo "$response" | jq -r '.[] | select(.name | endswith(".gitignore")) | .name' 2>/dev/null | sort)
    
    # Fallback to regex if jq is not available
    if [ $? -ne 0 ] || [ -z "$templates" ]; then
        templates=$(echo "$response" | grep -E '"name":\s*"[^"]*\.gitignore"' | sed -E 's/.*"name":\s*"([^"]*\.gitignore)".*/\1/g' | sort)
    fi
    
    echo "$templates"
}

# Function to ask for user confirmation
ask_confirmation() {
    local template_name=$1
    local target_file=$2
    
    # Extract friendly name for display
    friendly_name=$(echo "$template_name" | sed -E 's/\.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$//')
    
    print_color $YELLOW "Found exact match: $friendly_name"
    echo -n "Do you want to append this template to '$target_file'? [Y/n]: "
    read -r response
    
    case "$response" in
        [nN][oO]|[nN])
            print_color $BLUE "Operation cancelled."
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}
# Function to search for templates and handle smart default behavior
search_templates() {
    local search_term=$1
    local auto_confirm=$2
    local target_file=$3
    
    print_color $BLUE "Searching for templates containing '$search_term'..."
    
    response=$(curl -s "$GITHUB_API_BASE/contents" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        print_color $RED "Error: Failed to fetch template list from GitHub API"
        exit 1
    fi
    
    # Extract .gitignore files from JSON response
    all_files=$(echo "$response" | jq -r '.[] | select(.name | endswith(".gitignore")) | .name' 2>/dev/null)
    
    # Fallback to regex if jq is not available
    if [ $? -ne 0 ] || [ -z "$all_files" ]; then
        all_files=$(echo "$response" | grep -E '"name":\s*"[^"]*\.gitignore"' | sed -E 's/.*"name":\s*"([^"]*\.gitignore)".*/\1/g')
    fi
    
    # Debug: show what files we found (uncomment if needed)
    # echo "DEBUG: Found .gitignore files:" >&2
    # echo "$all_files" >&2
    
    # Search in the filename (case-insensitive)
    matches=$(echo "$all_files" | grep -i "$search_term")
    
    if [ -z "$matches" ]; then
        print_color $YELLOW "No templates found containing '$search_term'"
        print_color $BLUE "Trying fuzzy search..."
        # Try a broader search including the base name without .gitignore
        fuzzy_matches=$(echo "$all_files" | sed 's/\.gitignore$//' | grep -i "$search_term" | sed 's/$/.gitignore/')
        if [ -n "$fuzzy_matches" ]; then
            print_color $GREEN "Found similar templates:"
            echo "$fuzzy_matches"
        else
            print_color $YELLOW "No similar templates found. Try '$0 --list' to see all available templates."
        fi
        return 1
    fi
    
    # Count matches
    match_count=$(echo "$matches" | wc -l)
    
    if [ "$match_count" -eq 1 ]; then
        # Single match - smart default behavior
        template_name="$matches"
        
        if [ "$auto_confirm" = "true" ]; then
            friendly_name=$(echo "$template_name" | sed -E 's/\.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$//')
            print_color $GREEN "Found exact match: $friendly_name"
            print_color $BLUE "Auto-confirming append operation..."
            append_template "$template_name" "$target_file"
        else
            if ask_confirmation "$template_name" "$target_file"; then
                append_template "$template_name" "$target_file"
            fi
        fi
    else
        # Multiple matches - check for exact match of the base name (without .gitignore)
        # Look for exact match: search_term should match the basename exactly
        exact_match=""
        while IFS= read -r template; do
            basename=$(echo "$template" | sed -E 's/\.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$//')
            if [ "$(echo "$basename" | tr '[:upper:]' '[:lower:]')" = "$(echo "$search_term" | tr '[:upper:]' '[:lower:]')" ]; then
                exact_match="$template"
                break
            fi
        done <<< "$matches"
        
        # Show all matches first for context
        print_color $GREEN "Found $match_count templates matching '$search_term':"
        echo "$matches"
        echo ""
        
        if [ -n "$exact_match" ]; then
            # Found exact match among multiple results
            if [ "$auto_confirm" = "true" ]; then
                friendly_name=$(echo "$exact_match" | sed -E 's/\.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$//')
                print_color $GREEN "Found single match: $friendly_name"
                print_color $BLUE "Auto-confirming append operation..."
                append_template "$exact_match" "$target_file"
            else
                if ask_confirmation "$exact_match" "$target_file"; then
                    append_template "$exact_match" "$target_file"
                fi
            fi
        else
            # Multiple matches, no exact match - just show them
            print_color $BLUE "Use '$0 <template_name>' to add a specific template"
        fi
    fi
}

# Function to append gitignore template
append_template() {
    local template_name=$1
    local target_file=$2
    
    # Clean template name - remove any whitespace and ensure proper format
    template_name=$(echo "$template_name" | xargs)
    
    # If it doesn't end with .gitignore (case-insensitive), add it
    if [[ ! "$template_name" =~ \.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$ ]]; then
        template_name="${template_name}.gitignore"
    fi
    
    # Extract the friendly name (without .gitignore) for display
    friendly_name=$(echo "$template_name" | sed -E 's/\.[gG][iI][tT][iI][gG][nN][oO][rR][eE]$//')
    
    print_color $BLUE "Fetching $friendly_name template..."
    
    # Get the raw content URL
    content_url="https://raw.githubusercontent.com/github/gitignore/main/$template_name"
    
    # Fetch the template content
    template_content=$(curl -s "$content_url" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_color $RED "Error: Failed to fetch template '$template_name'"
        exit 1
    fi
    
    # Check if template exists (GitHub returns 404 page for non-existent files)
    if echo "$template_content" | grep -q "404: Not Found"; then
        print_color $RED "Error: $friendly_name template not found"
        print_color $YELLOW "Try running '$0 --list' to see available templates"
        exit 1
    fi
    
    # Create backup of existing .gitignore if it exists
    if [ -f "$target_file" ]; then
        cp "$target_file" "${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_color $YELLOW "Backup created: ${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Append template to .gitignore
    {
        echo ""
        echo "# ====================================="
        echo "# $friendly_name gitignore template"
        echo "# Added on $(date)"
        echo "# ====================================="
        echo "$template_content"
    } >> "$target_file"
    
    print_color $GREEN "Successfully appended $friendly_name template to '$target_file'"
}

# Parse command line arguments
POSITIONAL_ARGS=()
AUTO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            list_templates
            exit 0
            ;;
        -s|--search)
            if [ -z "$2" ]; then
                print_color $RED "Error: --search requires a search term"
                show_usage
                exit 1
            fi
            search_templates "$2" "false" "$GITIGNORE_FILE"
            exit 0
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -f|--file)
            if [ -z "$2" ]; then
                print_color $RED "Error: --file requires a file path"
                show_usage
                exit 1
            fi
            GITIGNORE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_color $RED "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Handle positional arguments
if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
    # Treat positional argument as search term with smart default behavior
    search_templates "${POSITIONAL_ARGS[0]}" "$AUTO_CONFIRM" "$GITIGNORE_FILE"
    exit 0
fi

# Handle append operation - no longer needed, removed

# If no arguments provided, show usage
show_usage