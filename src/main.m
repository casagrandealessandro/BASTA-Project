clear all;
clc;

%% FINGERPRINT GATHERING
% -------------------------------------------------------------------------

fp_dataset = {'fingerprint1.jpeg', 'fingerprint2.jpeg', ...
    'fingerprint3.jpg', 'fingerprint4.png', 'fingerprint5.jpeg', ...
    'fingerprint6.jpg', 'fingerprint7.jpeg', 'fingerprint8.jpeg', ...
    'fingerprint9.jpg', 'fingerprint10.jpeg'};

imagePath = fullfile('..','FingerprintImages_Dataset',fp_dataset{3});
fp = rgb2gray(mat2gray(double(imread(imagePath))));

% =========================================================================


%% IMAGE CLEANING & ENHANCEMENT
% -------------------------------------------------------------------------

figure("Name", "Original image vs Enhanced image");
subplot(1,2,1);
imshow(fp,[]);
title("Original image");

% Apply adaptive thresholding to separate foreground and background
binary_image = imbinarize(fp);

% Invert the binary image to make the background white and foreground black
inverted_image = imcomplement(binary_image);

% Remove small objects and fill holes in the inverted image
filtered_image = bwareaopen(inverted_image, 100);
filled_image = imfill(filtered_image, 'holes');

% Multiply the filled image with the grayscale image to remove background
background_removed_image = fp .* filled_image;

fp = background_removed_image;

% 1. Laplacian HPF in Fourier domain
F = fft2(fp);
[u,v] = size(F);
D_max = sqrt((u/2)^2 + (v/2)^2);  % max distance
H_lap = (u^2 + v^2) / (D_max^2);
F_filt_lap = F .* H_lap;
f_enhanced_lap = ifft2(F_filt_lap);

% 2. Gaussian LPF in Fourier domain
sigma = 20;
dist = distmatrix(size(abs(F),1), size(abs(F),2));
H_gau = exp(-(dist.^2) / (2 * sigma^2));
F_filt_gau = F .* H_gau;
f_enhanced_gau = ifft2(F_filt_gau);

% 3. HPF and LPF combination
f_enhanced = abs(f_enhanced_lap - f_enhanced_gau);

% 4. Edge extraction (Canny) and weighted summation
edges = edge(f_enhanced, 'Canny');
f_enhanced = f_enhanced + 0.5 * double(edges);

% Final result for enhanced image
subplot(1,2,2);
imshow(f_enhanced,[]);
title("Enhanced image");

% PSNR and SSIM
peaksnr = psnr(uint8(f_enhanced), uint8(fp));
ssimval = ssim(uint8(f_enhanced), uint8(fp));
disp("PSNR = " + peaksnr);
disp("SSIM = " + ssimval);

% Convert final double image to 8-bit [0..255]
f_enhanced = im2uint8(mat2gray(f_enhanced));

% =========================================================================


%% TCP/IP CONNECTION & DIFFIE-HELLMAN SYMMETRIC KEY EXCHANGE
% -------------------------------------------------------------------------

% Client connection to the server
client_socket = client_connection("localhost",12345);
% Gets client-server shared key using Diffie-Hellman procedure
shared_key = client_DiffieHellman(client_socket);

% =========================================================================


%% ENCRYPTION + WATERMARKING
% -------------------------------------------------------------------------

% Encryption of the first 7 planes using random shuffle algorithm, with
% seed based on the shared key

% Key conversion from vpi to 32 bytes long uint8 array
key_bytes = zeros(1, 32, 'uint8');
for i = 32:-1:1
    key_bytes(i) = double(mod(shared_key, 256));
    shared_key = floor(shared_key / 256);
end

% Flatten image into 1D bytes array
img_bytes = f_enhanced(:);

% Compute a unique seed from the key
seed = generate_seed(key_bytes);

% Set the random generator with the obtained seed
rng(seed, 'twister');

% Generate a random index sequence
N = numel(img_bytes);
perm_indices = randperm(N);

% Bit plane slicing
[rows,cols] = size(f_enhanced);
g = dec2bin(f_enhanced,8);
g = reshape(g', 8, rows * cols);

figure("Name","Bit plane slicing - encrypted planes")
f_encrypted = uint8(zeros(rows,cols));

for c = 1:7
    % Extract bit plane c
    x = reshape(g(c,:), rows, cols) - '0';
    % Encryption step: permutes the pixels
    x_encrypted = x(perm_indices);
    x_encrypted = reshape(x_encrypted, rows, cols);

    subplot(2,4,c);
    imshow(x_encrypted,[]);
    title("Plane " + c);

    % Rebuild partial encrypted image
    f_encrypted = f_encrypted + uint8(x_encrypted) .* 2^(8 - c);

    % Generate a new random index sequence
    perm_indices = randperm(N);
end

% Watermark addition to the last bit plane
imagePath = fullfile('..', 'images', 'watermark.tiff');
watermark = mat2gray(double(imread(imagePath)));
watermark = imresize(watermark,size(f_encrypted));
% Ensure the watermark is binary
watermark = watermark > 0.5;

subplot(2,4,8);
imshow(watermark,[]);
title("Plane 8 (watermark)");

% Add the watermark (least significant bit)
f_encrypted = f_encrypted + uint8(watermark);

f = figure("Name","Encrypted image");
ax = axes(f);
imshow(f_encrypted,[],'Parent',ax);
title(ax,"Encrypted image");

% =========================================================================


%% TRANSMISSION OVER TCP/IP
% -------------------------------------------------------------------------

write(client_socket,uint32(size(f_encrypted,1)));       % image height
write(client_socket,reshape(f_encrypted,1,[]),'uint8'); % raw bytes image