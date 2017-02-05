sudo ${HOME}/im2txt/bazel-bin/im2txt/run_inference   --checkpoint_path=${HOME}/im2txt/model/train   --vocab_file=/mnt/word_counts.txt   --input_files=$1
