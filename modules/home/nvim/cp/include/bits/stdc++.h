// bits/stdc++.h -- libstdc++ convenience header, reimplemented for libc++.
//
// WHY THIS EXISTS
// <bits/stdc++.h> is a GCC/libstdc++ internal header that transitively
// includes the entire standard library. It is not standard C++ and Apple's
// libc++ does not ship it. LeetCode and Codeforces both judge on GCC, so
// essentially every competitive C++ template starts with this include.
//
// Without this shim, every solution you pull down red-underlines on line 1
// and clangd gives you nothing for the rest of the file.
//
// This is used for LOCAL editing and compiling only. The judge uses its own
// real libstdc++ version, so nothing here changes what gets submitted.

#pragma once

// C library (C++ wrappers)
#include <cassert>
#include <cctype>
#include <cerrno>
#include <cfenv>
#include <cfloat>
#include <cinttypes>
#include <climits>
#include <clocale>
#include <cmath>
#include <csetjmp>
#include <csignal>
#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <cuchar>
#include <cwchar>
#include <cwctype>

// Containers
#include <array>
#include <bitset>
#include <deque>
#include <forward_list>
#include <list>
#include <map>
#include <queue>
#include <set>
#include <span>
#include <stack>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// General utilities
#include <algorithm>
#include <bit>
#include <chrono>
#include <compare>
#include <concepts>
#include <functional>
#include <initializer_list>
#include <iterator>
#include <limits>
#include <memory>
#include <numeric>
#include <optional>
#include <random>
#include <ranges>
#include <ratio>
#include <tuple>
#include <type_traits>
#include <typeindex>
#include <typeinfo>
#include <utility>
#include <variant>
#include <version>

// Strings and streams
#include <charconv>
#include <fstream>
#include <iomanip>
#include <ios>
#include <iosfwd>
#include <iostream>
#include <istream>
#include <ostream>
#include <regex>
#include <sstream>
#include <streambuf>
#include <string>
#include <string_view>

// Numerics
#include <complex>
#include <numbers>
#include <valarray>

// Diagnostics
#include <exception>
#include <stdexcept>
#include <system_error>

// Concurrency -- rarely needed for CP, but present in libstdc++'s version
#include <atomic>
#include <condition_variable>
#include <future>
#include <mutex>
#include <thread>

// Filesystem
#include <filesystem>
