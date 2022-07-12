all:
	./build.sh
	bochs

clean:
	rm -rf *.bin *.o kernel
