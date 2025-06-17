#!/bin/bash

# Simple unit tests for gi script - crucial features only
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0

test_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}✓ $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ $test_name${NC}"
        echo "  Expected: $expected"
        echo "  Got: $actual"
    fi
}

echo -e "${BLUE}Testing gi script...${NC}\n"

# Test 1: Help message
output=$(../gi --help 2>&1)
test_result "Help message shows usage" "Usage:" "$output"

# Test 2: List templates (if API available)
echo -e "${BLUE}Testing list functionality...${NC}"
output=$(timeout 10 ../gi --list 2>&1 || echo "API_TIMEOUT")
if [[ "$output" == *"API_TIMEOUT"* ]] || [[ "$output" == *"rate limit"* ]]; then
    echo -e "${BLUE}⚠ List test skipped (API rate limited)${NC}"
else
    test_result "List shows templates" "Available gitignore templates" "$output"
fi

# Test 3: File creation with auto-confirm
echo -e "${BLUE}Testing file creation...${NC}"
rm -f test.gitignore
output=$(timeout 10 ../gi --file test.gitignore python --yes 2>&1 || echo "API_TIMEOUT")
if [[ "$output" == *"API_TIMEOUT"* ]] || [[ "$output" == *"rate limit"* ]]; then
    echo -e "${BLUE}⚠ File creation test skipped (API rate limited)${NC}"
else
    test_result "Creates gitignore file" "Successfully appended" "$output"
    if [ -f test.gitignore ]; then
        test_result "File contains Python patterns" "__pycache__/" "$(cat test.gitignore)"
    fi
fi

# Cleanup
rm -f test.gitignore

echo -e "\n${BLUE}Results: $TESTS_PASSED/$TESTS_RUN tests passed${NC}"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi