use rusqlite::{Connection, Result};
use sha2::{Sha256, Digest};

fn calculate_hash(
    id: i32,
    name: &str,
    lat: f64,
    lng: f64,
    sensor_type: &str,
    created_at: &str,
    previous_hash: &str
) -> String {

    let mut hasher = Sha256::new();
    hasher.update(format!(
        "{}{}{}{}{}{}{}",
        id, name, lat, lng, sensor_type, created_at, previous_hash
    ));
    format!("{:x}", hasher.finalize())
}

fn main() -> Result<()> {

    let conn = Connection::open("sqlite.db")?;

    let mut stmt = conn.prepare(
        "SELECT id, name, lat, lng, sensor_type, created_at FROM sensor_positions ORDER BY id"
    )?;

    let rows = stmt.query_map([], |row| {
        Ok((
            row.get::<_, i32>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, f64>(2)?,
            row.get::<_, f64>(3)?,
            row.get::<_, String>(4)?,
            row.get::<_, String>(5)?,
        ))
    })?;

    let mut previous_hash = "0".to_string();

    for row in rows {
        let (id, name, lat, lng, sensor_type, created_at) = row?;

        let current_hash = calculate_hash(
            id,
            &name,
            lat,
            lng,
            &sensor_type,
            &created_at,
            &previous_hash
        );

        conn.execute(
            "UPDATE sensor_positions
             SET previous_hash = ?1, current_hash = ?2
             WHERE id = ?3",
            (&previous_hash, &current_hash, id),
        )?;

        previous_hash = current_hash;
    }

    println!("Blockchain hashes generated successfully.");

    Ok(())
}