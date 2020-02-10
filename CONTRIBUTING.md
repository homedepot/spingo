# Contributions Welcome

First off, thank you for considering contributing to this repository! This resource is a very simple project, but I am sure it has plenty of room for improvement.

If you're just looking for quick feedback for an idea or proposal, feel free to open an [issue](https://github.com/homedepot/spingo/issues/new).

Follow the [contribution workflow](#contribution-workflow) for submitting your changes.

## Contribution Workflow

This project uses the “fork-and-pull” development model. Follow these steps if you want to merge your changes into the project:

1. Within your fork of [spingo](https://github.com/homedepot/spingo), create a branch for your contribution and use a meaningful name.
2. Create your contribution, meeting all [contribution quality standards](#contribution-quality-standards).
3. [Create a pull request](https://help.github.com/articles/creating-a-pull-request-from-a-fork/) against the master branch.
4. Once the pull request is approved, one of the maintainers will merge it and build a release if needed. 

## Contribution Quality Standards

Your contribution needs to meet the following standards:

- All files and folders in [spingo](https://github.com/homedepot/spingo) are `kebab-case` - any new additions to [spingo](https://github.com/homedepot/spingo) must follow this convention unless an exception is noted.
- Separate each **logical change** into its own commit.
- Add a descriptive message for each commit. Follow [commit message best practices](https://github.com/erlang/otp/wiki/writing-good-commit-messages).
- Document your pull requests. Include the reasoning behind each change and describe the testing done.
- To the extent possible, follow existing code and documentation style and practices.
- Each contribution must pass a shellcheck and terraform validate test. 
