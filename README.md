# Creditcard Tokenizer

HTML iFrames for tokenizing and detokenizing credit card numbers using the AuricVault® tokenization service.

# Dependency

* AuricSystemsInternational/creditcard-validator

# Building Tokenizer and Detokenizer

* Run clean.sh to reinstall elm and node_module build artifacts and dependencies.
* Run `build.sh` to build the tokenizer and detokenizer.
* Use the tokenize.html and detokenize.html files in the sample-code directory to test the tokenize and detokenize functionality.

The `build.sh` script generates two Javascript files, one for tokenizer and one for detokenizer.
The script has parameters for compiling with debugging and optionally minifying the Javascript output (requires the minify tool be installed).

# Images

* This project uses icons from Shopify's free Credit Card Icon Set https://www.shopify.com/blog/6335014-32-free-credit-card-icons 

* The credit card images are assumed to be located in "images/creditcards" directory of the web site/application 

# Sample Code

The sample-code directory contains two parent HTML pages, one for tokenizing and one for detokenizing.
The `deploy-test.sh` script collects the compiled elm code and the sample code into a single repository for deploying to a test environment.

## Versioning

We use [SemVer](http://semver.org/) for versioning.
For the versions available, see the [tags on this repository](https://github.com/AuricSystemsInternational/creditcard-brand/tags).

## License

This project is licensed under the BSD 3-clause "New" or "Revised" license - see the [LICENSE](LICENSE) file for details.

## Contributors

* **Subrata Das**  - *Initial work* - [sd0s](https://github.com/sd0s)
