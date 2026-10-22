// The pattern cache (design section 6.4, D4): least recently used, keyed by
// pattern, flags, dialect, literal and JIT. Main thread only, so no lock.

#include <string.h>

#include "pattern.h"

static zuregex_pattern *slots[ZUREGEX_CACHE_MAX];
static int size = 0;
static int capacity = ZUREGEX_CACHE_DEFAULT;
static uint64_t tick = 0;
static double hits = 0, misses = 0, evictions = 0;

static int key_equal(const zuregex_key *a, const zuregex_key *b) {
  return a->length == b->length && a->options == b->options &&
         a->extra == b->extra && a->dialect == b->dialect &&
         a->literal == b->literal && a->jit == b->jit && a->utf == b->utf &&
         memcmp(a->pattern, b->pattern, a->length) == 0;
}

// UTF-8 characters in a byte string: every byte that does not continue a
// sequence starts one.
static size_t utf8_chars(const char *s, size_t n) {
  size_t chars = 0;
  for (size_t i = 0; i < n; i++) {
    if (((unsigned char) s[i] & 0xC0) != 0x80) chars++;
  }
  return chars;
}

static void evict(int i) {
  zuregex_pattern_release(slots[i]);
  slots[i] = slots[size - 1];
  slots[size - 1] = NULL;
  size--;
  evictions++;
}

static void evict_lru(void) {
  int oldest = 0;
  for (int i = 1; i < size; i++) {
    if (slots[i]->last_used < slots[oldest]->last_used) oldest = i;
  }
  evict(oldest);
}

zuregex_pattern *zuregex_cache_get(const zuregex_key *key, int use_cache,
                                   int *errcode, size_t *erroffset) {
  // A cache of capacity 0 holds nothing: compile without counting a miss.
  if (!use_cache || capacity == 0) {
    return zuregex_pattern_compile(key, errcode, erroffset);
  }
  for (int i = 0; i < size; i++) {
    if (key_equal(&slots[i]->key, key)) {
      hits++;
      slots[i]->last_used = ++tick;
      zuregex_pattern_retain(slots[i]);
      return slots[i];
    }
  }
  misses++;
  zuregex_pattern *p = zuregex_pattern_compile(key, errcode, erroffset);
  if (p == NULL) return NULL;
  if (capacity > 0 &&
      utf8_chars(key->pattern, key->length) <= ZUREGEX_CACHE_MAX_PATTERN) {
    if (size >= capacity) evict_lru();
    p->last_used = ++tick;
    zuregex_pattern_retain(p);  // the cache's reference
    slots[size++] = p;
  }
  return p;
}

int zuregex_cache_capacity(void) {
  return capacity;
}

int zuregex_cache_set_capacity(int n) {
  int previous = capacity;
  capacity = n;
  while (size > capacity) evict_lru();
  return previous;
}

int zuregex_cache_clear(void) {
  int n = size;
  while (size > 0) {
    zuregex_pattern_release(slots[size - 1]);
    slots[--size] = NULL;
  }
  return n;
}

zuregex_cache_stats zuregex_cache_get_stats(void) {
  zuregex_cache_stats s = {size, capacity, hits, misses, evictions};
  return s;
}
