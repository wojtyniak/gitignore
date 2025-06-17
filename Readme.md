# gitignore

Download and append .gitignore templates from the [github/gitignore](https://github.com/github/gitignore) repository to your local project.

## Why?

Tired of manually downloading .gitignore files or copying them between repos? This script makes it effortless to grab the right template and append it to your local `.gitignore`.

## Installation

Place the `gi` script somewhere in your `PATH`, for example:

```bash
wget https://raw.githubusercontent.com/wojtyniak/gitignore/refs/heads/master/gi -O ~/bin/gi
chmod +x ~/bin/gi
```

Note: Ensure `~/bin` is in your `PATH`.

## Usage

```bash
gi <keyword>
```

The script intelligently handles different search scenarios:

### Single match → Direct confirmation
```bash
$ gi swift
Searching for templates containing 'swift'...
Found exact match: Swift
Do you want to append this template to '.gitignore'? [Y/n]: y
Fetching Swift template...
Successfully appended Swift template to '.gitignore'
```

### Multiple matches with exact match → Smart suggestion
```bash
$ gi go
Searching for templates containing 'go'...
Found 3 templates matching 'go':
Go.gitignore
Godot.gitignore
IGORPro.gitignore

Found exact match: Go
Do you want to append this template to '.gitignore'? [Y/n]: y
Fetching Go template...
Successfully appended Go template to '.gitignore'
```

### Multiple matches, no exact match → Show options
```bash
$ gi ru
Searching for templates containing 'ru'...
Found 3 templates matching 'ru':
Drupal.gitignore
Ruby.gitignore
Rust.gitignore

Use './gi <template_name>' to add a specific template
```

## Features

- **Smart search**: Handles partial matches intelligently
- **Interactive confirmation**: Always asks before modifying your `.gitignore`
- **Append mode**: Adds to existing `.gitignore` instead of overwriting
- **No dependencies**: Single bash script, no Node.js or Python required
- **Official source**: Pulls directly from GitHub's template repository

## Testing

Run the provided test script:

```bash
cd test
./test_gi.sh
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.