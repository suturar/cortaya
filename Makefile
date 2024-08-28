all: cortaya shader.so
cortaya: ./main.odin
	odin build main.odin -error-pos-style:unix -debug -file -out:cortaya
shader.so: ./shader.odin
	odin build shader.odin -error-pos-style:unix -file -build-mode:shared -default-to-nil-allocator -no-entry-point -no-crt
