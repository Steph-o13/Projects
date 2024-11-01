# Image manipulation with Python

# DATA STRUCTURES AND ALGORITHMS

# notes:
# all pixels from images are in as numpy arrays in the 3D shape (Height, Width, 3)
# the 3 corresponds to the 3 color channels: Red, Green, Blue
# the : operator in numpy iterates over the entire range of that dimension or specified range
# indexing of arrays starts at 0, so as an example:
# the first pixel of the red channel is located at pixels[0,0,0]
# the upper ends of loops and numpy ranges are not inclusive, so [n,m] ends at m-1. 

# import packages
from abc import abstractmethod, ABC
import numpy as np
import PIL.Image  # type: ignore

# image effect class
class ImageEffect(ABC):
    @staticmethod
    @abstractmethod
    def apply(pixels: np.ndarray) -> np.ndarray:
        raise NotImplementedError


def pix_to_image(pixels: np.ndarray) -> PIL.Image.Image:
    pixels = np.minimum(pixels, 255)
    pixels = np.maximum(pixels, 0)
    return PIL.Image.fromarray(np.uint8(pixels))


def image_to_pix(image: PIL.Image.Image) -> np.ndarray:
    return np.asarray(image, dtype=np.int16)


def get_image(path: str) -> PIL.Image.Image:
    return PIL.Image.open(path)

# create variables to represent the color channels
red = 0
green = 1
blue = 2

# a class that has no effect on the image
class NoEffect(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        return pixels 

# a class that inverts the image
class Invert(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # NOTE: The following subtracts each element in the matrix from
        # 255 This is much faster than looping through the array because
        # numpy uses vectorized operations to accelerate the computation
        return 255 - pixels

# Removes all red shades from an image by setting the red channel to fully off (0) for all pixels
class NoRed(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Across all rows and columns, set the red values to 0
        pixels[:, :, red] = 0
        return pixels

# Removes all green shades from an image by setting the green channel to fully off (0) for all pixels
class NoGreen(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Across all rows and columns, set the green values to 0
        pixels[:, :, green] = 0
        return pixels

# Removes all blue shades from an image by setting the blue channel to fully off (0) for all pixels
class NoBlue(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Across all rows and columns, set the blue values to 0
        pixels[:, :, blue] = 0
        return pixels

# Retains only the red shades of an image by turning off the other 2 color channels
class RedOnly(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Set all values in the green and blue channels to 0
        pixels[:, :, [green, blue]] = 0
        return pixels

# Retains only the green shades of an image by turning off the other 2 color channels
class GreenOnly(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Set all values in the red and blue channels to 0
        pixels[:, :, [red, blue]] = 0
        return pixels

# Retains only the blue shades of an image by turning off the other 2 color channels
class BlueOnly(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Set all values in the red and green channels to 0
        pixels[:, :, [red, green]] = 0
        return pixels

# Returns image in grayscale by setting each pixel color channel to the average of the 3 at that location
class Grayscale(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Numpy mean returns mean color across each pixel via axis=2, the 3rd dimension of color
        mean_pix = np.mean(pixels, axis=2)
        pixels[:, :, red] = mean_pix[:, ]
        pixels[:, :, green] = mean_pix[:, ]
        pixels[:, :, blue] = mean_pix[:, ]
        return pixels

# Adds noise to an image by adding a random values between -5 and 5 to each red, green, and blue value
class Noiseify(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Create random integer array of the same shape with values -5 to 5, then add to pixels
        rand_pix = np.random.randint(low=-5, high=6, size=np.shape(pixels), dtype=np.int16)
        pixels = np.add(pixels, rand_pix)
        # Enforce rule that new values do not fall out of (0,255)
        pixels[pixels > 255] = 255
        pixels[pixels < 0] = 0
        return pixels

# Smooths an image by setting each pixel to the mean of it and its neighbors
class Smooth(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        # Create temporary input array and take the image's height and width as pix_r and pix_c (rows,columns)
        pix_in = np.copy(pixels)
        pix_shape = np.shape(pixels)
        pix_r = pix_shape[0]
        pix_c = pix_shape[1]
        # Iterate through each pixel in all 3 color channels to calculate individual mean using input array
        for i in range(0, pix_r):
            for j in range(0, pix_c):
                for k in range(0, 3):
                    # Create temporary variables for calculating mean, starting with the pixel of interest
                    temp_sum = pix_in[i, j, k]
                    temp_count = 1
                    # Add value at each of 8 neigboring pixels if they exist
                    # Neighbor 1 at [i-1,j-1]
                    if i - 1 >= 0 and j - 1 >= 0:
                        temp_sum += pix_in[i - 1, j - 1, k]
                        temp_count += 1
                    # Neighbor 2 at [i-1,j]
                    if i - 1 >= 0:
                        temp_sum += pix_in[i - 1, j, k]
                        temp_count += 1
                    # Neighbor 3 at [i-1,j+1]
                    if i - 1 >= 0 and j + 1 < pix_c:
                        temp_sum += pix_in[i - 1, j + 1, k]
                        temp_count += 1
                    # Neighbor 4 at [i,j-1]
                    if j - 1 >= 0:
                        temp_sum += pix_in[i, j - 1, k]
                        temp_count += 1
                    # Neighbor 5 at [i,j+1]
                    if j + 1 < pix_c:
                        temp_sum += pix_in[i, j + 1, k]
                        temp_count += 1
                    # Neighbor 6 at [i+1,j-1]
                    if i + 1 < pix_r and j - 1 >= 0:
                        temp_sum += pix_in[i + 1, j - 1, k]
                        temp_count += 1
                    # Neighbor 7 at [i+1,j]
                    if i + 1 < pix_r:
                        temp_sum += pix_in[i + 1, j, k]
                        temp_count += 1
                    # Neighbor 8 at [i+1,j+1]
                    if i + 1 < pix_r and j + 1 < pix_c:
                        temp_sum += pix_in[i + 1, j + 1, k]
                        temp_count += 1
                    # Calculate mean of the pixel and existing neighbors, assign to output array pixels
                    pixels[i, j, k] = temp_sum / temp_count
        return pixels

# Normalizes image by rescaling each color channel to ensure it contains a pixel with 0 and 255 intensity
class Normalize(ImageEffect):
    def apply(pixels: np.ndarray) -> np.ndarray:
        for i in range(0, 3):
            # Only does calculation when max != min to avoid dividing by 0
            if pixels[:, :, i].max() != pixels[:, :, i].min():
                # For each pixel subtract min of the channel then multiply by (max-min)*255
                # This multiplier = 1 when max and min of channel are already 255 and 0, so there is no effect
                pixels[:, :, i] = (pixels[:, :, i] - pixels[:, :, i].min()) / (
                        pixels[:, :, i].max() - pixels[:, :, i].min()) * 255
        return pixels

# Reduces colors in image to 8 by setting pixels to either fully on (255) or off (0) based on a threshold
class Threshold(ImageEffect):
    def apply(pixels: np.ndarray, cutoff: int = 127) -> np.ndarray:
        # Set lower bound to include the cutoff value because 255/2 is actually 127.5
        pixels[pixels > cutoff] = 255
        pixels[pixels <= cutoff] = 0
        return pixels

