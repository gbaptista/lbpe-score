# LBPE Score

This repository contains the source code used to evaluate and generate results for the LBPE Score. It also provides replication for the MMLU test.

You can read more about this in the article on Medium: [TODO](#)

Detailed charts with results: https://gbaptista.github.io/lbpe-score/

{index}

## Setup

```sh
git clone https://github.com/gbaptista/lbpe-score.git

cd lbpe-score

cp .env.example .env

docker compose up -d

bundle install
```

Ensure proper [setup and configuration](https://github.com/icebaker/ruby-nano-bots?tab=readme-ov-file#setup) of [Nano Bots](https://github.com/icebaker/ruby-nano-bots) for access to both ChatGPT and Gemini:

```sh
nb cartridges/models/standard/openai/gpt-4-turbo.yml - eval "Hi."
# Hello! How can I assist you today?

nb cartridges/models/standard/google/gemini-pro.yml - eval "Hi." 
# Hello! How may I assist you?
```

```sh
./lbpe version
```

```yaml
---
project: LBPE Score
version: 0.0.1
nano-bots:
  version: 2.2.0
  specification: 2.0.1
github: https://github.com/gbaptista/lbpe-score
```

Get the necessary data from the repository [`lbpe-score-data`](https://github.com/gbaptista/lbpe-score-data).


## Usage

```sh
./lbpe generate BENCHMARK SAMPLES-GENERATED-PER-INTERACTION TARGET-SAMPLES-NUMBER
./lbpe generate conversational-recall-1 10 100

./lbpe eval MODELS BENCHMARK
./lbpe eval standard conversational-recall-1

./lbpe eval MODELS BENCHMARK SAMPLE
./lbpe eval standard conversational-recall-1 data/datasets/conversational-recall-1/sample.yml

./lbpe eval MODELS BENCHMARK
./lbpe eval standard conversational-recall-1

./lbpe score BENCHMARK
./lbpe score conversational-recall-1

./lbpe score

./lbpe report
```

```sh
# Generate dataset samples:
./lbpe generate conversational-recall-1 10 100
./lbpe generate conversational-recall-2 10 100
./lbpe generate conversational-recall-3 10 100
./lbpe generate conversational-recall-4 10 100
./lbpe generate tools-1 10 100
./lbpe generate tools-2 10 100

# Evaluate models on generated samples:
./lbpe eval standard conversational-recall-1
./lbpe eval standard conversational-recall-2
./lbpe eval standard conversational-recall-3
./lbpe eval standard conversational-recall-4
./lbpe eval tools tools-1
./lbpe eval tools tools-2

# Score the evaluations:
./lbpe score

# Generate final report:
./lbpe report
```

To ensure scientific rigor, if you change any character in your cartridges or datasets, you will be required to run evaluations related to them again. Therefore, be cautious with changes; ensure the readiness of the datasets and cartridges before starting to spend money on generating samples and evaluations.

### MMLU

```sh
./lbpe generate MMLU dev # dev test val
./lbpe eval standard MMLU
./lbpe score
./lbpe report
```

## Disclaimer and Warning

To ensure scientific rigor, if you change any character in your cartridges or datasets, you will be required to run evaluations related to them again. Therefore, be cautious with changes; ensure the readiness of the datasets and cartridges before starting to spend money on generating samples and evaluations.

Keep in mind that running these benchmarks can be costly; we are talking about expenses ranging from $30 to $500, depending on how you iterate on it. Be careful and monitor your costs closely. The authors assume no responsibility for any damage or costs that may arise from the use of this project.

## Development

```sh
bundle
rubocop -A
```

### Charts
```sh
cd site
sudo npm install http-server -g
http-server -p 3000 --cors -c-1
```

### Updating the README

Install [Babashka](https://babashka.org):

```sh
curl -s https://raw.githubusercontent.com/babashka/babashka/master/install | sudo bash
```

Update the `template.md` file and then:

```sh
bb tasks/generate-readme.clj
```

Trick for automatically updating the `README.md` when `template.md` changes:

```sh
sudo pacman -S inotify-tools # Arch / Manjaro
sudo apt-get install inotify-tools # Debian / Ubuntu / Raspberry Pi OS
sudo dnf install inotify-tools # Fedora / CentOS / RHEL

while inotifywait -e modify template.md; do bb tasks/generate-readme.clj; done
```

Trick for Markdown Live Preview:
```sh
pip install -U markdown_live_preview

mlp README.md -p 8076
```
