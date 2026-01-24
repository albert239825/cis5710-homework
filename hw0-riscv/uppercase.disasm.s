
uppercase.bin:     file format elf32-littleriscv


Disassembly of section .text:

00010074 <_start>:
   10074:	ffff2517          	auipc	a0,0xffff2
   10078:	f8c50513          	addi	a0,a0,-116 # 2000 <__DATA_BEGIN__>

0001007c <loop>:
   1007c:	00054283          	lbu	t0,0(a0)
   10080:	02028263          	beqz	t0,100a4 <end_program>
   10084:	06100313          	li	t1,97
   10088:	0062c863          	blt	t0,t1,10098 <next>
   1008c:	07a00313          	li	t1,122
   10090:	00534463          	blt	t1,t0,10098 <next>
   10094:	fe028293          	addi	t0,t0,-32

00010098 <next>:
   10098:	00550023          	sb	t0,0(a0)
   1009c:	00150513          	addi	a0,a0,1
   100a0:	fddff06f          	j	1007c <loop>

000100a4 <end_program>:
   100a4:	0000006f          	j	100a4 <end_program>
