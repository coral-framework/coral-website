---
title: Getting Started
sort_key: /1
---

To use Coral you will need, in addition to the Coral SDK, a decent grounding in the [C++ programming language](http://en.wikipedia.org/wiki/C++) and [object-oriented programming](http://en.wikipedia.org/wiki/Object-oriented_programming). Familiarity with [component-based software engineering](http://en.wikipedia.org/wiki/Component-based_software_engineering) is useful but not required, since the fundamental concepts are introduced in the documentation.

# Installing the Coral SDK {#install}

Coral is released as source code only. Learning how to build the SDK is important and the process should be easy to follow. However, don't hesitate to [report any difficulties](/community) you might encounter so we can make things smoother!

## Prerequisites {#prerequisites}

Coral is written in standard C++ and does not depend on external libraries. The source code is mostly platform-agnostic, except for a few features such as dynamic libraries. Before continuing, please check our [list of supported platforms and compilers](../guides/portability#supported).

In addition to a supported compiler, you will need [CMake](http://www.cmake.org/) to configure and build the SDK. Coral adopts CMake as its official build system and this guide assumes you are somewhat familiar with it.

Finally, to run automated tests you must have the [GTest](https://code.google.com/p/googletest/) framework installed. This is optional but recommended in order to confirm the integrity of the SDK on your system. And if you want to use GTest in your project, the tutorials also show how to integrate it into the development cycle of a Coral module.

## Download Coral {#download}

Please choose one of the following:

### a) [Download ZIP file](https://github.com/libcoral/coral/archive/master.zip)

Get the latest stable source code release by downloading it directly from GitHub.

### b) [Clone or fork via GitHub](https://github.com/libcoral/coral)

Visit us on GitHub to clone or fork the Coral project and check our development branch.

## Prepare the Environment {#environment}

When building a project with CMake you must specify three directories:

SOURCE_DIR
: Where to find the source code. This is where you unzipped or cloned Coral. For example, `~/projects/coral`.

BINARY_DIR
: Where to build the project. Use a separate dir to avoid polluting the source tree. For example, `~/projects/coral/build`.

INSTALL_DIR
: Where to copy the installation files. Choose a more stable location, such as `~/sdk/coral`.

Set the environment variable `CORAL_ROOT` to point to Coral's _INSTALL_DIR_.

## Run CMake {#cmake_step}

With the source code in the _SOURCE_DIR_, you must now create an empty _BINARY_DIR_ and run CMake in it. The CMake variable `CMAKE_INSTALL_PREFIX` should be set to the _INSTALL_DIR_. For example:

~~~ terminal
~ $ cd ~/projects/coral
~/projects/coral $ mkdir build
~/projects/coral $ cd build
~/projects/coral/build $ cmake -DCMAKE_INSTALL_PREFIX=~/sdk/coral ..
~~~

Other options may be needed depending on your environment. If GTest is installed but CMake cannot find it, try setting the environment variable `GTEST_ROOT` to its install location.

In terms of generators, Coral works well with Xcode and Visual Studio, in addition to makefiles. All default build types are supported---Release, Debug, MinSizeRel and RelWithDebInfo. If you use makefiles you must set `CMAKE_BUILD_TYPE` when calling CMake; for example, `-DCMAKE_BUILD_TYPE=Release`.

## Compile the SDK {#compile_step}

Depending on your options, CMake should have generated either a makefile or an IDE project in _BINARY_DIR_. Now you can use your native build system to compile the SDK:

- If you are using makefiles, simply call <kbd>make</kbd>.
- If you are using an IDE, build the `ALL_BUILD` target.

## Compile and Run Tests {#tests_step}

If you ran CMake with GTest, it should have generated the `testsuites` target, which you must build before running the tests.

Build the `test` target to run the tests. Even without GTest it will still run a few smoke tests. On UNIX, if you have [Valgrind](http://valgrind.org/) installed, the tests will also run through Valgrind to check for memory errors.

## Install the SDK {#install_step}

If all tests have passed, you may install the SDK. To do this you build the `install` target. There is a catch, though: you must install in Release and Debug modes.

# Exploring the SDK {#exploring}

How the SDK is organized.

- `coral` --- the CORAL_ROOT
  - `bin`
  - `cmake`
  - `modules`
    - `co`
    - `lua`
  - `lib`

# Hello Coral {#hello}

To be continued.
