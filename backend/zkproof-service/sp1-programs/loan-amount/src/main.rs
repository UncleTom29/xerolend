// ============ sp1-programs/loan-amount/src/main.rs ============

#![no_main]
sp1_zkvm::entrypoint!(main);

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct AmountInput {
    pub commitment: String,
    pub loan_amount: u64,
    pub min_amount: u64,
    pub max_amount: u64,
    pub salt: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AmountOutput {
    pub commitment: String,
    pub min_amount: u64,
    pub max_amount: u64,
    pub is_valid: bool,
}

pub fn main() {
    let input = sp1_zkvm::io::read::<AmountInput>();

    // Verify amount is within range
    let is_in_range = input.loan_amount >= input.min_amount 
        && input.loan_amount <= input.max_amount;

    // Verify commitment
    let computed_commitment = compute_commitment(&input.loan_amount.to_string(), &input.salt);
    let commitment_valid = computed_commitment == input.commitment;

    let output = AmountOutput {
        commitment: input.commitment,
        min_amount: input.min_amount,
        max_amount: input.max_amount,
        is_valid: is_in_range && commitment_valid,
    };

    sp1_zkvm::io::commit(&output);
}

fn compute_commitment(value: &str, salt: &str) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(value.as_bytes());
    hasher.update(salt.as_bytes());
    format!("{:x}", hasher.finalize())
}