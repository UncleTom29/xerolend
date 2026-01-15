// ============ sp1-programs/reputation/src/main.rs ============

#![no_main]
sp1_zkvm::entrypoint!(main);

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct ReputationInput {
    pub commitment: String,
    pub nullifier: String,
    pub user_score: u32,
    pub threshold: u32,
    pub loan_history: Vec<LoanRecord>,
    pub salt: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LoanRecord {
    pub loan_id: u64,
    pub amount: u64,
    pub repaid: bool,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ReputationOutput {
    pub commitment: String,
    pub nullifier: String,
    pub threshold: u32,
    pub is_valid: bool,
}

pub fn main() {
    let input = sp1_zkvm::io::read::<ReputationInput>();

    // Calculate reputation score from loan history
    let calculated_score = calculate_reputation(&input.loan_history);

    // Verify score meets threshold
    let meets_threshold = calculated_score >= input.threshold;

    // Verify commitment
    let computed_commitment = compute_commitment(
        &input.user_score.to_string(),
        &input.nullifier,
        &input.salt
    );
    let commitment_valid = computed_commitment == input.commitment;

    let output = ReputationOutput {
        commitment: input.commitment,
        nullifier: input.nullifier,
        threshold: input.threshold,
        is_valid: meets_threshold && commitment_valid && calculated_score == input.user_score,
    };

    sp1_zkvm::io::commit(&output);
}

fn calculate_reputation(history: &[LoanRecord]) -> u32 {
    if history.is_empty() {
        return 0;
    }

    let repaid_count = history.iter().filter(|l| l.repaid).count();
    let total_count = history.len();
    
    // Simple reputation: (repaid / total) * 100
    ((repaid_count as f32 / total_count as f32) * 100.0) as u32
}

fn compute_commitment(score: &str, nullifier: &str, salt: &str) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(score.as_bytes());
    hasher.update(nullifier.as_bytes());
    hasher.update(salt.as_bytes());
    format!("{:x}", hasher.finalize())
}
