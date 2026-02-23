use ethers::prelude::*;
use std::sync::Arc;
use std::env;
use dotenv::dotenv;
use std::fs;
use serde_json::Value;
use ethers::abi::Abi;
use std::str::FromStr;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {

    dotenv().ok();

    let rpc_url = env::var("RPC_URL")?;
    let private_key = env::var("PRIVATE_KEY")?;
    let contract_address = env::var("CONTRACT_ADDRESS")?;

    let provider = Provider::<Http>::try_from(rpc_url)?;
    let wallet: LocalWallet = private_key.parse()?;
    let client = SignerMiddleware::new(provider, wallet);
    let client = Arc::new(client);

    let abi_string = fs::read_to_string("abi.json")?;
    let abi: Abi = serde_json::from_str(&abi_string)?;

    let contract = Contract::new(
        Address::from_str(&contract_address)?,
        abi,
        client.clone(),
    );

    let sensor_id: u64 = 1;
    let data_hash = "example_hash_string";

    let tx = contract
        .method::<_, H256>("registerSensor", (sensor_id, data_hash.to_string()))?
        .send()
        .await?;

    println!("Transaction sent: {:?}", tx.tx_hash());

    Ok(())
}