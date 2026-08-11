# Changelog

## [2.0.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.9.3...v2.0.0) (2026-08-11)


### ⚠ BREAKING CHANGES

* **runner:** callers that rely on the implicit ubuntu-latest default now land on [self-hosted, local] instead. Anyone who genuinely needs a GitHub-hosted runner (e.g. a matrix build targeting macOS/Windows) must now pass runner: '["ubuntu-latest"]' explicitly.

### Bug Fixes

* **ci:** fall back to ubuntu-latest when runner input is empty ([#151](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/151)) ([33fbd44](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/33fbd441595d70af7b4c4f042ecc2b97e0de3861))
* **ci:** pin own internal CI to ubuntu-latest — public repo can't use self-hosted ([#149](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/149)) ([ca56176](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ca56176da813cd4702f2a93dafecdfcf46fc3297))
* **ci:** remove redundant standalone scorecards.yml ([#148](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/148)) ([ed0154b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ed0154b4c55e6dffc3549eb3e9b9c0bed965ddc7))
* **runner:** default the runner input to self-hosted, not ubuntu-latest ([#147](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/147)) ([9b4b016](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/9b4b0166ec652665b5f37e03766eccc202419e51))

## [1.9.3](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.9.2...v1.9.3) (2026-08-07)


### Bug Fixes

* **codeql:** install Go before autobuild ([#144](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/144)) ([1047dcb](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/1047dcb3bb267c7672fcdea90d6deac71c7a6fe0))
* **osv:** skip repositories without package sources ([#142](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/142)) ([f067432](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/f067432eac0bcfacd56b95b629881ada03bae3d2))
* **scorecard:** accept legacy publish input ([#143](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/143)) ([9c53c87](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/9c53c87abf754792bfbf5f94dec9b9df17fc092f))
* **shellcheck:** resolve $(dirname "$0") sourcing via -P SCRIPTDIR ([#145](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/145)) ([fba4a4a](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/fba4a4ae47d3b9722322ae2f89ebcb6fccbef1de))

## [1.9.2](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.9.1...v1.9.2) (2026-08-03)


### Bug Fixes

* **dispatch:** hardcode default deployer_repo owner to FelipeFuhr ([#140](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/140)) ([ffbebe7](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ffbebe7395fc62701826ae23cc7c5b9aec11d658))

## [1.9.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.9.0...v1.9.1) (2026-08-03)


### Bug Fixes

* **grype:** capture exit code + add 6 new reusable workflows ([#120](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/120)) ([0b3cb39](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/0b3cb39dcedfff1b322c6d395dbd49e9edbb441a))
* **promote-gate:** acquire dev-access cookie before health check ([#139](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/139)) ([c7b164c](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/c7b164ca66671ef277ac977b46cdebb6e708d37e))

## [1.9.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.8.1...v1.9.0) (2026-08-01)


### Features

* add general-ansible-lint reusable workflow ([#123](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/123)) ([41d52d9](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/41d52d95cba4044d8efc64d335e9c3dc66afc9c9))

## [1.8.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.8.0...v1.8.1) (2026-07-29)


### Bug Fixes

* **lefthook:** sync remote configs in the heavy-tier workflow too ([#135](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/135)) ([0dda7d7](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/0dda7d7d826599eda2419a59f37af0dc6a97fff3))

## [1.8.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.7.1...v1.8.0) (2026-07-29)


### Features

* add `runner` input to actionlint/config-validate/gitleaks/shellcheck ([#124](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/124)) ([ed85f5d](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ed85f5d86978d772269afecbfe526669ecedf324))
* **runner:** add opt-in `runner` input to remaining reusable workflows ([#126](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/126)) ([73d9a03](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/73d9a038a3fa9147af0d7717d09d6ca71d39fa6b))


### Bug Fixes

* **grype:** use relative/glob exclusion patterns for grype &gt;= 0.114.0 ([#129](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/129)) ([80d54b3](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/80d54b36b6b087033e2ede41a5739bb1e7ba2b49))
* **lefthook:** sync remote configs before running hooks in CI ([#134](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/134)) ([9c35c13](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/9c35c13b03bbf17b10a8ea3672ee7b3baadbb9db))
* pin unpinned action refs and drop npm global install in markdownlint ([#128](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/128)) ([db27e4b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/db27e4b6ef21f495a979411b4b4ad25f5cfa2e25))
* private-repo CI gaps (orphaned typos SHA, pr-size label, GHAS/Sonar entitlement) ([#130](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/130)) ([d2bee96](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/d2bee968dbba2a38de4a7d87290f4cf6e9658084))
* **semgrep:** install semgrep with --user for self-hosted runner compat ([#127](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/127)) ([eed1897](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/eed18971e3eefa381877231fcb3f510117687be8))

## [1.7.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.7.0...v1.7.1) (2026-06-27)


### Bug Fixes

* orphaned dependency-review SHA + gitleaks comment-guard false-positive ([#121](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/121)) ([b2b0084](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/b2b0084a62265a79a16a7ec04a6f56b464e1bfc1))

## [1.7.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.6.0...v1.7.0) (2026-06-25)


### Features

* **ci:** remove general-quality-seo and general-quality-live workflows ([#113](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/113)) ([1178fcd](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/1178fcdb8ee4baede5d630afabd26e8ecf82b0bf))


### Bug Fixes

* **gitleaks:** restrict allowlist grep to line-start only ([4746335](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/474633563723ef7b055ca9af2c00564dd217d03e))
* **grype:** capture exit code with || to survive shell -e flag ([18fd5ef](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/18fd5efa47d47bdc4cc9418ea5b26f88246772f8))
* **grype:** exclude grype binary from its own filesystem scan ([#119](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/119)) ([9bc50ce](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/9bc50ce3a8973a01e2ae2c5a5dca437e6de99c81))
* **grype:** exit-on-error + add 6 new reusable workflows (checkov, dep-review, markdownlint, pr-size, sbom, typos) ([#118](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/118)) ([3adec90](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/3adec9071fcbfa4c008ba1c8d0b9947307e89eed))

## [1.6.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.5.0...v1.6.0) (2026-06-12)


### Features

* **fleet:** add FLEET_SPOT_CI gate + grype-pr-diff to templates ([45165d8](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/45165d8fa75cae27bfc2b551c0a09f4245f61fc0))
* **grype:** add general-grype-pr-diff reusable workflow ([e979e12](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/e979e126dd2cba87717399ebe92d1b3c0de36b0a))
* **runner:** add runner input for AWS Spot routing (cron + push-to-main) ([773f0ad](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/773f0ad0aa056dff88e018ed05731a8579bdf247))

## [1.5.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.4.3...v1.5.0) (2026-06-10)


### Features

* add 6 new reusable workflows to bridge CI gaps ([#99](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/99)) ([3563c9c](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/3563c9cd6e6282d53b2e203d35c502a3dd13901f))
* add general-claude-judge reusable workflow ([#97](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/97)) ([bdf9f68](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/bdf9f68c3803f8450f55c4ea046ac7116d9c67e8))
* add general-config-validate reusable workflow (yamllint + JSON parse) ([#103](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/103)) ([6df3e6e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/6df3e6e4a50f91f1102aaf372063228323a5a5a2))
* **ci-local:** drift-gate reusable workflow (general-ci-local-coverage.yml) ([#100](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/100)) ([12c4171](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/12c41714d56ff512e8093cd96a2ab11e60aced17))


### Bug Fixes

* resolve SonarQube issues ([#98](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/98)) ([6c0f6ec](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/6c0f6ec2fa4d3f83f2be03142b101b9e71e158b4))
* resolve SonarQube script injection vulnerabilities ([#93](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/93)) ([bb6031b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/bb6031b2cbacb1f231382648ec4ab0d5512ad85d))

## [1.4.3](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.4.2...v1.4.3) (2026-06-06)


### Bug Fixes

* **ci:** unique concurrency group in reusable workflows to avoid caller deadlock ([#91](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/91)) ([5c855ba](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/5c855ba62fe77d82a30d30a8d68a7abe61bbc850))

## [1.4.2](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.4.1...v1.4.2) (2026-06-06)


### Bug Fixes

* **grype:** install to /usr/local/bin to prevent self-scan false positives ([#88](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/88)) ([e60967b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/e60967b314a4615c1c30e2d8540cc36141dc3e02))

## [1.4.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.4.0...v1.4.1) (2026-06-04)


### Bug Fixes

* **lefthook:** install golangci-lint v2.11.4 (go1.25-compatible) ([#86](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/86)) ([5037bfe](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/5037bfec00fda302746bb966f78c1de375375b64))

## [1.4.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.3.2...v1.4.0) (2026-06-04)


### Features

* **ci:** consolidate quality (live/seo) + lefthook complex/release reusables ([#80](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/80)) ([af85524](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/af855243d05e036007e857272f2e267623ac9b01))

## [1.3.2](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.3.1...v1.3.2) (2026-06-03)


### Bug Fixes

* **ci:** grant id-token:write to scorecard caller (fixes ci.yml startup_failure) ([#82](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/82)) ([0527768](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/052776800d7289f63c1efe678af1268b62117e16))

## [1.3.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.3.0...v1.3.1) (2026-06-03)


### Bug Fixes

* **ci:** reference declared input secret names in reusable workflows ([#77](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/77)) ([4ceb370](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/4ceb3700a2b6fa17ffbb9979b2b8c1cabb4e3487))
* **security-fs:** retry grype on transient empty SARIF; trim redundant ci.yml self-tests ([#79](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/79)) ([082210e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/082210e4ff52877b0f3c5398132ed5defdbeed21))

## [1.3.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.2.3...v1.3.0) (2026-06-03)


### Features

* **promote-gate:** pass for CI-only (.github/) PRs — nothing to promote ([#71](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/71)) ([99da6e8](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/99da6e813180cd6b6c7923112b0e31969a2fb067))


### Bug Fixes

* **promote-gate:** detect CI-only via git diff (contents:read), not gh api ([#74](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/74)) ([2fdb717](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/2fdb7171ac630a6ce0b21fe7e641644310da0f59))
* **promote-gate:** robust CI-only detection (grep -c count, not ! grep -q) ([#73](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/73)) ([a09060e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/a09060e4a41ab2700e46a31a6f92d26876493940))

## [1.2.3](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.2.2...v1.2.3) (2026-05-26)


### Bug Fixes

* ci ([#55](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/55)) ([0d27144](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/0d27144a6f59dc99f5dd6e583b31400d51eb7040))

## [1.2.2](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.2.1...v1.2.2) (2026-05-26)


### Bug Fixes

* ensure grype.sarif is written ([#51](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/51)) ([7393724](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/7393724e7da9494df981522dfaf8cdb3d20f3a96))

## [1.2.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.2.0...v1.2.1) (2026-05-24)


### Bug Fixes

* bump github/codeql-action pin past orphaned SHA b25d0ebf → v4.36.0 ([#45](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/45)) ([39fe386](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/39fe386ceda4d99d22af96c1c85e71639588d5f3))
* **ci:** remove duplicate timeout-minutes in dependency-review ([#43](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/43)) ([10b1d21](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/10b1d2131317de5df0747f82c6e1c6dab6a97244))

## [1.2.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.1.0...v1.2.0) (2026-05-22)


### Features

* add general-kb-sync reusable workflow ([#42](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/42)) ([56b4af8](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/56b4af8ba7d8702c524597196e5b8643fe6b49ac))
* add general-promote-gate reusable workflow ([#38](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/38)) ([23226b0](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/23226b0ad6e547e6760c9dc36f77cd680fa6deef))

## [1.1.0](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.0.4...v1.1.0) (2026-05-09)


### Features

* add general-website-dispatch reusable workflow ([#37](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/37)) ([7a17afb](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/7a17afb611f7ebb0264d71b9afa2ae9f58b2ab10))
* **ci:** add general-semgrep, scorecard publish-results, and platform-standards migration ([#34](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/34)) ([745f58b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/745f58b17437f71d918ac7f4d632cd7dcac68f23))

## [1.0.4](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.0.3...v1.0.4) (2026-05-05)


### Bug Fixes

* **semantic-pr:** fix scope regex using double backslashes in raw f-string ([#32](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/32)) ([0f1515e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/0f1515effa075090424a42f5d21551fba271dd60))

## [1.0.3](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.0.2...v1.0.3) (2026-05-02)


### Bug Fixes

* ci ([#29](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/29)) ([fef6709](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/fef6709c20dd4485f680cdf32d2cb97226c549ad))

## [1.0.2](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.0.1...v1.0.2) (2026-05-02)


### Bug Fixes

* ci ([#27](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/27)) ([4bd5e73](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/4bd5e73f654fa89e476ef381973f3db387bf6505))

## [1.0.1](https://github.com/FelipeFuhr/ffreis-workflows-general/compare/v1.0.0...v1.0.1) (2026-05-02)


### Bug Fixes

* ci ([#25](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/25)) ([2dd0846](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/2dd084690728e48bac7ca7d47d2206741dc0792c))

## 1.0.0 (2026-05-02)


### Features

* add CodeQL upload-sarif toggle ([4d172a1](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/4d172a1173de321a35fed920fa091ba681ba86c9))
* ci ([b99f5a3](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/b99f5a3e0c87c6cc45f630b7bc24a0cc6eba148e))
* ci ([8b0def0](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/8b0def05cb9c3aae519fc46dd2131870fa66a261))
* ci ([ad13396](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ad13396c258f03d5835edfe7c86259cff0c9b6a3))
* ci ([67fbc7b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/67fbc7bc637eb8c43cb276dd64cd0181a63a456f))
* improve behavior ([a0bdc41](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/a0bdc4104fe85d3b30d0f7521d64aa7736ccfc74))
* improve behavior ([894a178](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/894a1783af140b7a44fcc11cb831198c75c62e53))
* make grype fs scan non-blocking ([2b7128a](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/2b7128a66369c51be86df393242a4ba3ab47aec1))
* more workflows ([3354e66](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/3354e66cc3a7eb558b01c367c330293cc767b6ee))
* more workflows ([1649f24](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/1649f2467f005aac8b07632c5027dc4c36328f96))
* update shas ([#7](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/7)) ([7645147](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/76451474435b95f5314cce2dbaf56e7bc158f119))
* update workflows ([510fa18](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/510fa18cb916d2fe30251e4fae2726335028d5fa))


### Bug Fixes

* address PR review comments on hooks and Makefile ([f2c8a9b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/f2c8a9b1345945d92782e57b4d663bc4878e0b58))
* ci ([#11](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/11)) ([7856d93](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/7856d93b40e8b691eff639514c73c3e4ca1c9a71))
* ci ([#12](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/12)) ([c209344](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/c209344cb05c33f56a8a43f516765fdc13cc8dd8))
* ci ([#13](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/13)) ([cb9a55f](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/cb9a55f734fdf436d66a15c486bce4e3e5607985))
* ci ([#14](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/14)) ([68e501b](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/68e501b54df5b56f3016f04faf90ad7f473635b5))
* ci ([#15](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/15)) ([8fe7f6d](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/8fe7f6d430fedc05eec2dbe85dbec4e67f73da23))
* ci ([#16](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/16)) ([4e890b9](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/4e890b90b69038a7971011fc75c614e4ba6d76df))
* ci ([#17](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/17)) ([570f5c1](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/570f5c11593a6d1f73b7d3ad94240cfc9d8b3cce))
* ci ([#20](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/20)) ([2091b8d](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/2091b8d1e6284db40ef4da0ba6f86f823acf209f))
* ci ([#22](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/22)) ([51e5a5f](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/51e5a5f2bfdd3a7d5c26b60dc3e76986152b3fd8))
* ci ([#23](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/23)) ([535842e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/535842e074e48b9716d289a5d484e36ee64a4fda))
* codeql actions source-root ([d314ba8](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/d314ba861af9f908b6a90910a4e120cb869d45c2))
* ensure grype.sarif is written ([c3e3e0a](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/c3e3e0a44d4b79697f1babaa9bf287d1b264da52))
* harden git hooks and Makefile tooling based on PR review ([cd834ff](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/cd834ffd19f4cf2cef228d8f261db82768e88348))
* improve ([a5fa9bf](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/a5fa9bf46109db27b07271242b23661b8828a276))
* improve ([78a176f](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/78a176f121db7ed63fc5f1387fbcc168e5eecff2))
* improve ci ([57eb793](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/57eb7931df140778320ad28cd5a63cbb11c553ba))
* labeler creates missing labels ([e21de09](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/e21de09012e38e75ca0bf2bd1ad73ac2b79f5b2a))
* labeler retry on 422 ([ffdd797](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/ffdd797688b0e6ce485ad6af028bc31c90153fdc))
* move policy scan_file section [#3](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/3) inside function, fix labeler top-level return, document devops workflow exception in AGENTS.md ([d2761bf](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/d2761bf885b644521cc4bff0356ca67d535c9d66))
* repair broken Python in general-workflows-policy and general-labeler; document devops-* exemption ([983a8e1](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/983a8e1b647407fad6ac236a1adab80467c6f582))
* use osv-scanner reusable workflow ([9e30611](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/9e306114fe3e81abe64127898e032335e3420f95))
* workflow ([fc5fcac](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/fc5fcac8c2cfe0ccd8d18b73383df445ec31e371))
* workflow ([c3436c5](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/c3436c5a6ff32cfa42a401079a2b09e7724fccdf))
* workflows ([#10](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/10)) ([932109e](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/932109ee060877cf695d302b6b384d012fb9ac9f))
* workflows ([#8](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/8)) ([8cbf0fe](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/8cbf0fe3a3b21df8a7be6f0b465453894565f9d3))
* workflows ([#9](https://github.com/FelipeFuhr/ffreis-workflows-general/issues/9)) ([bec0d4f](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/bec0d4f3129a75a50fa8803a20877aa85db45476))
* workflows-policy script indentation ([0853887](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/08538870a247838d332cddbd75f448a8d6e402c0))
* workflows-policy yaml heredoc indentation ([a501721](https://github.com/FelipeFuhr/ffreis-workflows-general/commit/a501721afa38faeeb889dce8d59f7a0fb66ba27d))
