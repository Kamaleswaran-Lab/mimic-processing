import os
import gzip
import shutil

def decompress_gz_files(input_dir, output_dir):
    for root, dirs, files in os.walk(input_dir):
        # Recreate folder structure in output directory
        relative_path = os.path.relpath(root, input_dir)
        target_dir = os.path.join(output_dir, relative_path)
        os.makedirs(target_dir, exist_ok=True)

        for file in files:
            if file.endswith(".csv.gz"):
                input_file = os.path.join(root, file)
                output_file = os.path.join(target_dir, file[:-3])  # remove .gz extension

                # Decompress file
                with gzip.open(input_file, 'rb') as f_in:
                    with open(output_file, 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)

                print(f"Decompressed: {input_file} -> {output_file}")

if __name__ == "__main__":
    input_directory = "/hpc/home/yy450/link_kamaleswaranlab/mimic_iv/mimic-iv-3.1"   # change this
    output_directory = "/hpc/home/yy450/link_kamaleswaranlab/mimic_iv/mimic-iv-3.1-decompress" # change this
    decompress_gz_files(input_directory, output_directory)
