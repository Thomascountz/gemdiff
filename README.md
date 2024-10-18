# GemDiff

GemDiff is a tool for comparing different versions of Ruby gems using `diffoscope`.

## Prerequisites

- Ruby
- Bundler (Install via: `gem install bundler`)
- `diffoscope` (Install via Homebrew: `brew install diffoscope`)

## Installation

1. Clone the repository:
    ```sh
    git clone <repository-url>
    cd <repository-directory>
    ```

## Usage

1. Run the script:
    ```sh
    ./gemdiff/gemdiff.rb
    ```

2. Follow the prompts to:
    - Choose a gem source (pull from `gem sources`, e.g. `~/.gemrc`).
    - Enter the gem name.
    - Select two versions to compare.

3. The specified gem versions are fetched and cached in the `.cache/` directory.

4. An HTML diff is generated using `diffoscope` and saved in the `out/` directory.

## Directories

- `.cache/`: This directory is used to store cached `.gem` files to avoid re-fetching them.
- `out`/: This directory is used to store the generated HTML diff files.

## Example

```sh
./gemdiff/gemdiff.rb
```

Follow the interactive prompts to complete the comparison.
