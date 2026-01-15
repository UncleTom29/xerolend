// ============ sp1-programs/collateral-value/src/main.rs ============

#![no_main]
sp1_zkvm::entrypoint!(main);

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct CollateralInput {
    pub commitment: String,
    pub collateral_value: u64,
    pub min_value: u64,
    pub salt: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct CollateralOutput {
    pub commitment: String,
    pub min_value: u64,
    pub is_valid: bool,
}

pub fn main() {
    // Read input from stdin
    let input = sp1_zkvm::io::read::<CollateralInput>();

    // Verify collateral value >= min_value
    let is_valid = input.collateral_value >= input.min_value;

    // Verify commitment
    let computed_commitment = compute_commitment(&input.collateral_value.to_string(), &input.salt);
    let commitment_valid = computed_commitment == input.commitment;

    let output = CollateralOutput {
        commitment: input.commitment,
        min_value: input.min_value,
        is_valid: is_valid && commitment_valid,
    };

    // Write output
    sp1_zkvm::io::commit(&output);
}

fn compute_commitment(value: &str, salt: &str) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    hasher.update(salt.as_bytes());
    format!("{:x}", hasher.finalize())
}