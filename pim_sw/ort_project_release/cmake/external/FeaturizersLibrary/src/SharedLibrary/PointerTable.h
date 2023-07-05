// ----------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License
// ----------------------------------------------------------------------
#pragma once

#include <mutex>
#include <random>
#include <stdexcept>
#include <unordered_map>

#include <assert.h>

namespace Microsoft{
namespace Featurizer{

/////////////////////////////////////////////////////////////////////////
///  \class         PointerTable
///  \brief         Provide an interface to store pointers in exchange of
///                 an index to avoid exposing pointers to users
///
class PointerTable {
public:
    // ----------------------------------------------------------------------
    // |
    // |  Public Methods
    // |
    // ----------------------------------------------------------------------
    PointerTable(unsigned int seed=(std::random_device())());

    template<typename T>
    size_t Add(const T* const toBeAdded);

    template<typename T>
    T* Get(size_t index);

    void Remove(size_t index);

private:
    // ----------------------------------------------------------------------
    // |
    // |  Private Types
    // |
    // ----------------------------------------------------------------------
    using LockGuard                         = std::lock_guard<std::mutex>;

    // ----------------------------------------------------------------------
    // |
    // |  Private Data
    // |
    // ----------------------------------------------------------------------
    std::unordered_map<std::size_t, const void *>       m_un;
    std::mutex                                          m_un_mutex;
    std::mt19937                                        m_mt;
};


// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// |
// |  Implementation
// |
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
// ----------------------------------------------------------------------
inline PointerTable::PointerTable(unsigned int seed) : m_mt(seed) {

}


template<typename T>
size_t PointerTable::Add(const T * const templatePointer) {
    if (templatePointer == nullptr) {
        throw std::invalid_argument("Trying to add a null pointer to the table!");
    }


    void const * const                      toBeAdded(reinterpret_cast<const void* const>(templatePointer));
    size_t                                  empty_index(0);

    {
        LockGuard const                     lock(m_un_mutex);

        std::ignore = lock;

        // since we are controlling where and how to use PointerTable and Add function
        // it wouldn't worth the cost to have two maps with atomic insertions
        // check for duplicates at run time
        // comparing to the chance of adding the same pointer twice,
        // so we would only check for duplicates in debug mode
#if (defined DEBUG)
            for (auto pairs : m_un) {
                assert(pairs.second != toBeAdded);
            }
#endif

        // size would be changing throughout the process
        // index zero is reserved
        std::uniform_int_distribution<size_t>           dist(1,std::numeric_limits<std::size_t>::max());

        while(true) {
            size_t rand_index = dist(m_mt);
            if (m_un.find(rand_index) == m_un.end()) {
                empty_index = rand_index;
                break;
            }
        }
        assert(empty_index != 0);
        m_un[empty_index] = toBeAdded;
    }

    return empty_index;
}

template<typename T>
T* PointerTable::Get(size_t index) {
    // pre-check
    if (index == 0) {
        throw std::invalid_argument("Invalid query to the Pointer table, index cannot be zero!");
    }

    LockGuard const                         lock(m_un_mutex);

    std::ignore = lock;

    std::unordered_map<std::size_t, const void*>::const_iterator found = m_un.find(index);
    if (found == m_un.end()) {
        throw std::invalid_argument("Invalid query to the Pointer table, index incorrect!");
    }

    return reinterpret_cast<T*>(const_cast<void*>(found->second));
}


inline void PointerTable::Remove(size_t index) {
    // pre-check
    if (index == 0) {
        throw std::invalid_argument("Invalid remove from the Pointer table, index cannot be zero!");
    }

    LockGuard const                         lock(m_un_mutex);

    std::ignore = lock;

    std::unordered_map<std::size_t, const void*>::const_iterator found = m_un.find(index);
    if (found == m_un.end()) {
        throw std::invalid_argument("Invalid remove from the Pointer table, index pointer not found!");
    }

    m_un.erase(found);
}

} // namespace Featurizer
} // namespace Microsoft
