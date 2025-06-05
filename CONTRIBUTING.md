# Welcome

Welcome! We are glad you are interested in contributing to the Serverless GCP Sample Apps. This guide will help you understand the requirements and guidelines to improve your contributor experience.

## Contributing to code

### Bug fixes

If you have identified an issue that is already labeled as `type/bug` that hasn’t been assigned to anyone, feel free to claim it, and ask a maintainer to add you as assignee.
Once you have some code ready, open a PR, [linking it to the issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/linking-a-pull-request-to-an-issue#manually-linking-a-pull-request-to-an-issue-using-the-pull-request-sidebar). Take into account that if the changes to fix the bug are not trivial, you need to follow the RFC process as well to discuss the options with the maintainers.

### Setting up your development environment

Each of the sample apps has a unique environment. It is documented in the associated README.md file. All of these apps will require Google Cloud access as well.

If there is a `format.sh` script in a directory, please run that before committing your changes.

## Contributing to issues

### Contributing to reporting bugs

If you think you have found a bug in the Serverless GCP Sample Apps feel free to report it. When creating issues, you will be presented with a template to fill. Please, fill as much as you can from that template, including steps to reproduce your issue, so we can address it quicker.

### Contributing to triaging issues

Triaging issues is a great way to contribute to an open source project. Some actions you can perform on an open by someone else issue that will help addressing it sooner:

- Trying to reproduce the issue. If you can reproduce the issue following the steps the reporter provided, add a comment specifying that you could reproduce the issue.
- Finding duplicates. If there is a bug, there might be a chance that it was already reported in a different issue. If you find an already reported issue that is the same one as the one you are triaging, add a comment with "Duplicate of" followed by the issue number of the original one.
- Asking the reporter for more information if needed. Sometimes the reporter of an issue doesn’t include enough information to work on the fix, i.e. lack of steps to reproduce, not specifying the affected version, etc. If you find a bug that doesn’t have enough information, add a comment tagging the reporter asking for the missing information.
