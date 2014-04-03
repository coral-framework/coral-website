---
title: Portability
---

Coral is designed for _source-code portability_, meaning that modules can be built for different platforms from one code base. However, dynamic libraries are not _binary portable_ and must be re-compiled for each platform and compiler.

Because C++ doesn't guarantee binary compatibility _across compilers_, Coral will always check, before loading a module, if it was compiled by the same compiler that compiled the framework. This is one of several automatic safety checks that prevent obscure crashes due to binary incompatibility.

# Supported platforms {#supported}
{: .page-header}

|    OS   | Architectures  |        Compilers         |
|---------|----------------|--------------------------|
| Linux   | x86_32, x86_64 | GCC 4.5 or later         |
| OSX     | x86_64         | Clang 3.0 or later       |
| Windows | x86_32, x86_64 | Visual C++ 2010 or later |
{: .table .table-striped }

# Adding support for new platforms {#adding}
{: .page-header}

Coral is largely written in standard C++, which is fairly portable. However, things such as loading dynamic libraries are only possible through OS-specific APIs, and may not even be available in all platforms.

To facilitate the job of porting Coral to new platforms, this section lists the required platform features and known locations of platform-specific code.

## Required platform features

- Support for POSIX.1
- Hierarchical filesystem
- Double-precision floats (IEEE 754 binary64)
- Dynamically-linked libraries (DLL/DSO)

## Known platform-specific parts of the source code

- The `<co/Platform.h>` header file
- The reserved `co::OS` class
- The internal `co::Library` class
- The built-in `ModulePartLoader` component
- The `coral` and `launcher` executables

Please, let us know if you find any platform-specific code that is not listed here.
