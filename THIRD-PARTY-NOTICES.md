# Third-party notices

**The `LICENSE` file at the root of this repository (MIT) covers the packaging only** - `Package.swift`,
`Sources/SPFKJXL/`, the tests, the script and the README. It does **not** cover `Sources/libjxl/` or
`Sources/libbrotli/`, which are third-party code under their own terms. All four are permissive.

| Component | Where | License | Text |
|---|---|---|---|
| [libjxl](https://github.com/libjxl/libjxl) | `Sources/libjxl/lib/` | BSD 3-Clause, with Google's patent grant | [`Licenses/libjxl-LICENSE.txt`](Licenses/libjxl-LICENSE.txt), [`Licenses/libjxl-PATENTS.txt`](Licenses/libjxl-PATENTS.txt) |
| [Highway](https://github.com/google/highway) | `Sources/libjxl/third_party/highway/` | BSD 3-Clause, chosen from its Apache 2.0 / BSD 3-Clause dual license | [`Licenses/highway-LICENSE-BSD3.txt`](Licenses/highway-LICENSE-BSD3.txt) |
| [skcms](https://skia.googlesource.com/skcms) | `Sources/libjxl/third_party/skcms/` | BSD 3-Clause | [`Licenses/skcms-LICENSE.txt`](Licenses/skcms-LICENSE.txt) |
| [Brotli](https://github.com/google/brotli) | `Sources/libbrotli/` | MIT | [`Licenses/brotli-LICENSE.txt`](Licenses/brotli-LICENSE.txt) |

Versions: libjxl's release tag, and the commits of the other three that it pins, are in
[`upstream-versions.txt`](upstream-versions.txt).

## Required attribution

Each license requires a binary redistribution to reproduce its copyright notice and conditions in the documentation
or other materials. Applications embedding this package should carry all four license texts in an About box or
acknowledgements panel.

The libjxl patent grant covers claims licensable by Google that the implementation necessarily infringes, and ends
for anyone who brings patent litigation over it. It says nothing about third-party patents.
