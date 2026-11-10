use std::thread;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Item {
    value: i32,
    original_index: usize,
}

fn radix_sort(items: &mut Vec<Item>, workers: usize) {
    assert!(workers > 0, "Worker count must be positive");
    if items.is_empty() { return; }
    let workers = workers.min(items.len());
    let chunk_size = items.len().div_ceil(workers);
    // Four stable passes: least significant byte first.
    for byte in 0..4 {
        let groups = thread::scope(|scope| {
            let handles: Vec<_> = items.chunks(chunk_size).map(|chunk| {
                scope.spawn(move || {
                    let mut buckets: [Vec<Item>; 256] = std::array::from_fn(|_| Vec::new());
                    for &item in chunk {
                        let key = (item.value as u32) ^ 0x8000_0000;
                        let digit = ((key >> (byte * 8)) & 0xff) as usize;
                        buckets[digit].push(item);
                    }
                    buckets
                })
            }).collect();
            // Join in source-chunk order, not completion order.
            handles.into_iter().map(|h| h.join().expect("Worker panicked"))
                .collect::<Vec<_>>()
        });
        items.clear();
        for digit in 0..256 {
            for buckets in &groups {
                items.extend_from_slice(&buckets[digit]);
            }
        }
    }
}

fn main() {
    let values = [170, -45, 75, -90, 802, 24, 2, 66, -45, 0,
                  i32::MIN, i32::MAX, -1, 170];
    let input: Vec<_> = values.iter().enumerate()
        .map(|(original_index, &value)| Item { value, original_index }).collect();
    let mut result = input.clone();
    radix_sort(&mut result, 4);
    let mut expected = input.clone();
    expected.sort_by_key(|item| item.value);
    assert_eq!(result, expected);
    println!("Input:  {:?}", values);
    println!("Sorted: {:?}", result.iter().map(|x| x.value).collect::<Vec<_>>());
    println!("Workers: 4; byte passes: 4");
    println!("Stable order (value, original zero-based index):");
    for value in [-45, 170] {
        let positions: Vec<_> = result.iter().filter(|x| x.value == value)
            .map(|x| x.original_index).collect();
        println!("{value}: {positions:?}");
    }
    println!("CHECK PASSED: sorted values and stable order match reference");
}

#[cfg(test)]
mod tests {
    use super::*;
    fn check(values: &[i32]) {
        let input: Vec<_> = values.iter().enumerate()
            .map(|(original_index, &value)| Item { value, original_index }).collect();
        let mut expected = input.clone();
        expected.sort_by_key(|x| x.value);
        for workers in [1, 2, 3, 4, 16] {
            let mut actual = input.clone();
            radix_sort(&mut actual, workers);
            assert_eq!(actual, expected, "workers={workers}");
        }
    }
    #[test]
    fn edges_and_duplicates() {
        for values in [vec![], vec![7], vec![5; 31],
            vec![i32::MAX, 0, i32::MIN, -1, 1, i32::MIN, i32::MAX],
            vec![-256, -255, -1, 0, 1, 255, 256, 65535, 65536]] {
            check(&values);
        }
        check(&(0..100).collect::<Vec<_>>());
        check(&(0..100).rev().collect::<Vec<_>>());
    }
    #[test]
    fn generated_full_width_and_repeated_keys() {
        let mut seed = 123456789_u32;
        for size in [2, 17, 257, 4096] {
            let values: Vec<_> = (0..size).map(|_| {
                seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
                seed as i32
            }).collect();
            check(&values);
            check(&values.iter().map(|x| x % 11).collect::<Vec<_>>());
        }
    }
}
