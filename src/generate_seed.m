function seed = generate_seed(key_bytes)

    % Compute SHA-256 hash using Java
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(key_bytes);
    % Convert signed bytes to uint8
    hash = typecast(md.digest(), 'uint8');

    % Extract the first 4 bytes to form a 32-bit seed
    seed_bytes = hash(1:4);
    seed = double(typecast(seed_bytes, 'uint32'));
end