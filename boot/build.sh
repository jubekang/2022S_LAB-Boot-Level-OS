cd lib
nasm -f elf64 -o syscall.o syscall.asm
nasm -f elf64 -o lib.o lib.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c print.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ar rcs lib.a print.o syscall.o lib.o
cp lib.a ../user1
cp lib.a ../user2
cp lib.a ../user3
cp lib.a ../test
rm lib.a
rm *.o
cd ..

cd test
nasm -f elf64 -o start.o start.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -Tlink.lds -o user start.o main.o lib.a 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary user test.bin
mv test.bin ../bin
rm *.o user
cd ..

cd ls
nasm -f elf64 -o start.o start.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -Tlink.lds  -o user start.o main.o lib.a 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary user ls
mv ls ../bin
rm *.o user
cd ..

cd totalmem
nasm -f elf64 -o start.o start.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -Tlink.lds  -o user start.o main.o lib.a 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary user totalmem
mv totalmem ../bin
rm *.o user
cd ..

cd user2
nasm -f elf64 -o start.o start.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -Tlink.lds -o user start.o main.o lib.a 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary user user.bin
mv user.bin ../bin
rm *.o user
cd ..

cd loader
nasm -f bin -o loader.bin loader.asm
nasm -f elf64 -o entry.o entry.asm
nasm -f elf64 -o liba.o lib.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c print.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c debug.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c file.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -T link.lds -o entry entry.o main.o liba.o print.o debug.o file.o
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary entry entry.bin
dd if=entry.bin >> loader.bin
dd if=loader.bin of=../os.img bs=512 count=15 seek=1 conv=notrunc
rm -rf *.bin *.o entry
cd ..

# nasm -f bin -o boot.bin boot.asm
# nasm -f bin -o loader.bin loader.asm
nasm -f elf64 -o kernel.o kernel.asm
nasm -f elf64 -o trapa.o trap.asm
nasm -f elf64 -o liba.o lib.asm
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c trap.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c print.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c debug.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c memory.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c process.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c syscall.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c lib.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c keyboard.c
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-gcc -std=c99 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c file.c 
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-ld -nostdlib -T link.lds -o kernel kernel.o main.o trapa.o trap.o liba.o print.o debug.o memory.o process.o syscall.o lib.o keyboard.o file.o
/usr/local/gcc-4.8.1-for-linux64/bin/x86_64-pc-linux-objcopy -O binary kernel kernel.bin
mv kernel.bin ./bin
# dd if=boot.bin of=os.img bs=512 count=1 conv=notrunc
# dd if=loader.bin of=boot.img bs=512 count=5 seek=1 conv=notrunc