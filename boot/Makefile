all:
	./build.sh

.PHONY: bin

bin:
	./build.sh
	rm -rf *.o kernel
	cp *.bin bin

old:
	./build_old.sh
	bochs

clean:
	rm -rf *.bin *.o kernel

cleano:
	rm -rf *.o kernel
