all:
	./build.sh
	bochs

clean:
	rm -rf *.bin *.o kernel lib.a
	cd ./lib
	rm -rf *.o
	cd ..
	cd ./user
	rm -rf lib.a *.o user
	cd ..