#   @(#)wdboot.s	2.1 
#
#	This is the system bootloader.  It implements the functionality
#	specified in the System V/68 General Disk Bootloader specification
#	with the following exceptions and additions:
#
#	1) The VMEbug software abort functionality is supported for
#	debugging purposes.
#
#	2) An object file name may be passed from the VMEbug boot
#	command to the bootloader. Either a full path name or a path name
#	which assumes the present working directory is root, may be used.
#
#	3) The default object file need not be in the root directory
#	if its path is specified as follows:
#		[<up to 13 chars>,0 ]...<up to 13 chars> 0,0
#	For example:  name: byte 's,'t,'a,'n,'d,0,'s,'a,'s,'h,0,0
#	might be used to specify the standalone shell.
#
#	4) This revision is compatible with the SGS2 a.out file format.
#	It expects to be placed between the superblock and the inodes
#	and requires bootvec0.s to provide the information the VMEbug
#	monitor boot command needs to find and load this module.
#	
#	5) The VMEbug disk read routine is used instead of including another
#	disk read routine here. This approach depends on several values
#	from VMEbug expected in registers when the bootloader begins execution.
#
#	6) The drive number and controller number being booted from 
#	are passed to the operating system.
#
#  Bootloader Algorithm
#
#	 Fetch parameters passed in registers
#	 Repeat while components left in search path
#	    Execute get_inode for directory 
#	    Repeat while no match && blocks left in directory
#	       Execute read_next_block to get directory data block
#	       Repeat while no match && not out of directory entries
#	          If inode number is null
#		     error terminate
#	          Compare name to directory entry
#	       end repeat
#	    end repeat
#	    If no match 
#	       error terminate
#	 end repeat
#	 Execute get_inode for load module
#	 Read header into buffer
#	 If magic is MC68MAGIC
#           Get two more blocks into buffer
#	    Move vectors from buffer to text_start
#	    Skip over VMERAM area in memory and a.out file
#	    Move remaining code from buffer to memory
#	    Load remaining blocks into memory
#	    If data_start != textsize + text_start
#	       move datasize bytes into position at data_start
#	    Set entry address from header
#	 Else
#	    Load all blocks into memory beginning at address 0
#	    Set entry address to 0
#	 Jump to entry address
#
#-----------------------------------------------------------------------
# Conventions & Assumptions
#
#	Block numbers run from 0-n on the disk device.
#	Inode numbers run from 1-n beginning in block 1.
#
# Register conventions:
#	a6		- frame pointer
#	a5		- buffer pointer
#	a4		- target name pointer
#	a3		- directory entry pointer
#	d7		- long block number
#	d6		- long current inode number
#	d5		- long file block number*4
#	d0-d4,a0-a2	- scratch registers

# Data Structures
	set	BLKSIZ,1024		# no. bytes/block
	set	HDRSIZ,168		# bytes in header
	set	MC68MAGIC,0520		# expected file type
	set	BOOTSIZ,1024
	set	INOSIZ,64		# no. bytes/inode entry
	set	INOBLK,BLKSIZ/INOSIZ	# no. inodes/disc block
	set	INOMSK,0xf		# inode to block mask
	set	NAMSIZ,14		# no. bytes in name field of dir entry
	set	DIRSIZ,16		# size of directory entry, bytes
	set	ROOTINO,2		# root dir inode no.
	set	PATHLIM,18		# char limit for specified path
		# make sure default name (name:... ) defines PATHLIM chars
	set	FILL,0
	set	CLR,0
# Inode structure
	set	inode,0
	set	mode,inode
	set	nlink,mode+2
	set	uid,nlink+2
	set	gid,uid+2
	set	size,gid+2
	set	faddr,size+4
	set	time,faddr+40
# Header structure
	set	filehdr,0
	set	f_magic,filehdr		# long magic number
	set	tsize,f_magic+24	# long size of text
	set	dsize,tsize+4		# long size of data
	set	entry,dsize+8		# long entry point
	set	text_start,entry+4	# long base of text
	set	data_start,text_start+4	# long base of data
					# other header info not used
# VME/10 Specific Constants
	set	VMERAM,0x0		# 1.5k ram used by VMEbug
# load module now made to start above ram no longer requires bootloader 
# to worry about the ram area.

# Winchester Disk Constants		(wdc = winchester disk controller)
	set	SPB,4			# 4 sectors (256 byte) per block
# Other Constants, Variables and Offsets 
	set	HIGH,0x30000
	set	STACK,HIGH
	set	BUFSIZ,BLKSIZ*3		# 3k buffer area
	set	FRAMEPTR,HIGH+BOOTSIZ+BUFSIZ	# data reference pointer 
	set	T,BOOTSIZ+BUFSIZ	# Text offset from frame pointer
	set	NT,4*266		# blkno[null terminator]
	set	SAVREGS,0x71e		# d5-d7,a3-a6
	set	GETREGS,0x78e0		# d5-d7,a3-a6
	set	VECS,0x400		# Vector area is 1k for 68k machines
	set	BLK2INDEX,8		# byte offset of 3rd long in blkno[]



# Bootloader Entry Info Expected by VMEbug

	org	0
boot:
	long	STACK			# initial stack pointer
	long	bootup+HIGH		# bootloader entry

# Default load module name

name:	byte	's,'t,'a,'n,'d,0
	byte	'u,'n,'i,'x,0,0
	byte	0,0,0,0,0,0		# PATHLIM chars defined in all
	byte	0,0			# double null terminator
	even

# Arguments received from VMEbug

dev:	byte	CLR			# boot device drive number
ctlr:	byte	CLR			# controller number
	even
cfcode:	long	CLR			# disk configuration code (byte 5)
cfadr:	long	CLR			# configuration data address
ioadr:	long	CLR			# controller io address
readr:	long	CLR			# read routine address


# Bootloader entry


bootup:
	mov.l	%a6,%a4			# save end of name pointer
	mov.l	&FRAMEPTR,%a6		# set data reference pointer
	mov.b	%d0,dev-T(%a6)		# save boot device drive number
	mov.b	%d1,ctlr-T(%a6)		# save controller number
	mov.l	%d2,cfcode-T(%a6)	# save disk configuration code
	mov.l	%a0,ioadr-T(%a6)	# save controller io address
	mov.l	%a2,cfadr-T(%a6)	# save configuration data adr
	mov.l	%a3,readr-T(%a6)	# save read routine address
	mov.l	%a5,%a3			# save name pointer
	lea.l	-BUFSIZ(%a6),%a5	# set buffer pointer

# Get object file name if passed from boot command

	cmp.l	%a3,%a4			# if default name is OK
	beq.b	boot8			#    go get started
	cmp.b	(%a3),&'/		# skip leading /
	bne.b	boot3
	add.l	&1,%a3
boot3:
	mov.w	&PATHLIM-1,%d0		# move up to PATHLIM chars (-1 for dbcc)
	lea.l	name+HIGH,%a0		# point to search key area

boot4:
	mov.b	(%a3)+,%d1		# get character
	cmp.b	%d1,&'/			# change / to null
	bne.b	boot5
	clr.b	%d1
boot5:
	cmp.b	%d1,&'A			# map UPPER to lower
	blo.b	boot6
	cmp.b	%d1,&'Z
	bhi.b	boot6
	add.b	&'a-'A,%d1
boot6:
	mov.b	%d1,(%a0)+		# save this one
	cmp.l	%a3, %a4		# until all are fetched
	dbhs	%d0, boot4		#    || count run out

	clr.b	(%a0)+			# double null terminate path
	clr.b	(%a0)

boot8:
	mov.l	&ROOTINO,%d6		# inode for root directory (inode 2)
	lea.l	name+HIGH,%a4		# Point to search key

# Repeat while components left in search path

boot10:	bsr	iget			# Get_inode for directory
	clr.l	%d5			# Clear file_block_number

#    Repeat while no match && blocks left in directory

boot11:	tst.l	0(%a6,%d5.l)		# If blkno[file_block_no] is null
err11:	beq.b	err11			#    out of blocks & out of luck
	bsr	rdnblk			# read_next_block to get directory data block
	mov.l	%a5,%a3			# reset directory entry pointer

#       Repeat while no match && not out of directory entries

	lea.l	BLKSIZ(%a5),%a2		# Point above 1k block
boot12:	cmp.l	%a3,%a2			# If entry pointer beyond buffer
	bhs.b	boot11			#    go try another block
	mov.w	(%a3)+,%d6		# Get inode number
	mov.l	%a3,%a0			# Point to directory entry
	add.l	&NAMSIZ,%a3
	tst.w	%d6			# If inode number is null
	beq.b	boot12			#    go try another entry

#          Compare name to directory entry

	mov.w	&NAMSIZ-1,%d0		# Check up to NAMSIZ chars (-1 for dbcc)
	mov.l	%a4,%a1			# Point to start of current component
boot13:	cmp.b	(%a0)+,(%a1)+		# If characters not equal
	bne.b	boot12			#    go try another entry
	tst.b	-1(%a1)			# If null terminator found
boot14:	dbeq	%d0,boot13		#    || count run out
					#         drop thru we have a match

#       end repeat
#    end repeat
# until end of path is reached

	ext.l	%d6			# Make inode number long
	mov.l	%a1,%a4			# Advance current component ptr
	tst.b	(%a4)			# Check for second null terminator
	bne.b	boot10			#   at end of path

# Found the object module

	bsr	iget			# Get_inode for load module
	clr.l	%d5			# Set file_block_number to 0
	bsr	rdnblk			# Get first block
boot15:	bne.b	boot15			# Terminate on null file
	cmp.w	f_magic(%a5),&MC68MAGIC	# If magic number OK
	beq.b	boot20			#    go use header info

# Assume image with entry at location 0

	clr.l	%d5			# Reset file_block_number to 0
	sub.l	%a5,%a5			# Set bufptr to location zero
	bsr	load			# Load all blocks into memory
	sub.l	%a2,%a2			# Set entry address to loc 0
	bra.b	boot50			# Go execute image

# Magic number recognized, use header info

boot20: # Get next two blocks into buffer
	add.l	&BLKSIZ,%a5		# move destination pointer
	bsr	rdnblk			# read next block
boot21:	bne.b	boot21			# terminate if block doesn't exist
	cmp.l	%d5,&BLK2INDEX		# is next block index pointing to blk 2?
	beq.b	boot20			# gets file blocks 0,1 & 2 in the buffer
	sub.l	&BLKSIZ*2,%a5		# restore buffer pointer

boot30:	# Move vectors to text_start

	mov.w	&VECS/4-1,%d0		# longs to move (-1 for dbra)
	mov.l	text_start(%a5),%a0	# to text_start
	lea.l	HDRSIZ(%a5),%a1		# from buffer
boot31:	mov.l	(%a1)+,(%a0)+		# move vectors
	dbra	%d0,boot31

	# skip VMERAM area in memory and throw away VMERAM padding in a.out

	add.l	&VMERAM,%a0		# skip VMERAM memory
	add.l	&VMERAM,%a1		# skip VMERAM padding in a.out

	# move code above fill to memory above VMERAM

	mov.w	&(BUFSIZ-VECS-VMERAM-HDRSIZ)/4-1,%d0 # longs to move (-1)
boot32:	mov.l	(%a1)+,(%a0)+		# move code above fill
	dbra	%d0,boot32

	# move remaining blocks into memory

	mov.l	%a5,%a4			# save buffer ptr
	mov.l	%a0,%a5			# starting where we left off
	bsr.b	load			# load remaining blocks
	mov.l	%a4,%a5			# restore buffer ptr

	mov.l	text_start(%a5),%a0	# if text_start + textsize
	add.l	tsize(%a5),%a0
	mov.l	data_start(%a5),%a1
	cmp.l	%a0,%a1			#  == data_start
	beq.b	boot37			#    go skip data movement

	# move data into position

	mov.l	dsize(%a5),%d0
	add.l	%d0,%a0			# from text_start + tsize + dsize
	add.l	%d0,%a1			#   to data_start + dsize
	lsr.l	&2,%d0			# dsize/4 longs to move
	sub.w	&1,%d0			#    (-1 for dbra)
boot35:	mov.l	-(%a0),-(%a1)		# in reverse order
	dbra	%d0,boot35

boot37:	mov.l	entry(%a5),%a2		# get entry address
	

boot50:

# pass drive and controller number to operating system

	clr.l	%d0
	mov.b	dev-T(%a6),%d0		# boot device drive number
	clr.l	%d1
	mov.b	ctlr-T(%a6),%d1		# controller number

# Jump to entry address

	jmp	(%a2)			# Jump to entry address


# Subroutine load
#
# Loads file blocks specified by array blkno[] starting with block
# blkno[file_block_no], into successive locations in memory beginning
# at start_loc.
#		d5 = long file_block_no*4
#		a5 = start_loc
#		d5, a5 modified
#

load:					# Repeat while not out of blocks
	bsr	rdnblk			#    Execute read_next_block 
	tst.l	0(%a6,%d5.l)
	beq.b	load1
	add.l	&BLKSIZ,%a5		#    bufptr = bufptr + BLKSIZ
	bra.b	load
load1:					# end repeat
	rts				# return

# Subroutine get_inode
#
#  Gets inode whose number is in d6
#  It assumes a5 is pointing to the buffer to be used.
#  Generates a list of the block numbers in the file (266 max),
#  fetching the first indirect block if necessary.
# 		d6 = unsigned long inodenumber and is modified
#		a5 = buffer pointer

iget:

# Get block containing specified inode

	add.l	&31,%d6			# inode_blk = (inode_no + 31) / 16
	mov.l	%d6,%d7
	lsr.l	&4,%d7
	bsr.b	rdblk			# read_block(inode_blk  buffer_ptr)
	
# extract first 11 block numbers from inode disk address field

	and.l	&INOMSK,%d6		# offset = (inode_no+31)mod 16)*64
	lsl.l	&6,%d6		
	lea.l	faddr(%a5,%d6.l),%a0	# faddr + buffer addr +  offset
	mov.l	%a6,%a1			# point to blkno[0] 
	mov.l	&10,%d0			# 11 addresses to unpack (-1 for dbra)
iget1:
	clr.b	(%a1)+			# convert 3 byte field to a long
	mov.b	(%a0)+,(%a1)+
	mov.b	(%a0)+,(%a1)+
	mov.b	(%a0)+,(%a1)+
	dbra	%d0,iget1		# til done

# if an indirect block exists, read( indirect_block  blkno[10])

	mov.l	-(%a1),%d7		# if blkno[10] != 0
	beq.b	iget2
	mov.l	%a5,-(%sp)		#  save buffer pointer
	mov.l	%a1,%a5			#  point to &blkno[10]
	bsr.b	rdblk			#  read( indirect_block  blkno[10])
	mov.l	(%sp)+,%a5		#  restore buffer pointer
	clr.l	NT(%a6)			#  set terminating null in blkno[NT]
iget2:
	rts				# return

# Subroutine read_next_block
#
#	Reads block number blkno[file_block_no] if it is not null.
#	It assumes a5 is pointing to the buffer to be used.
#	It postincrements file_block_no.
#	Upon return, the zero flag will be set if a block was read.
#		d5 = long file_block_no*4
#		a5 = buffer pointer
#		d7 modified

rdnblk:
	mov.l	0(%a6,%d5.l),%d7	# get blkno[file_block_no] 
	bne.b	rdn1			# exit if null
	mov.w	&CLR,%cc		# clear zero flag in ccr
	rts
rdn1:	add.l	&4,%d5			# increment file_block_no
#	bra.b	rdblk			# read block and return

# Subroutine read_block
#
#	Reads block number d7 into buffer pointed to by a5
#		 d7 = long block number
#	(block numbers begin at 0 and each block contains 1024 bytes)
#		 a5 = long buffer pointer
#	(buffer size is 1024 bytes)
#	Returns zero flag set on successful io, terminates on bad io.

rdblk:					# wdc = winchester disk controller

	movm.l	&SAVREGS,-(%sp)

# calculate and load arguments for read command to VMEbug
	
	mov.l	%a5,%d2			# buffer address
	mov.l	%d7,%d3
	lsl.l	&2,%d3			# starting sector = block * 4
	mov.l	&SPB,%d0		# sectors per block
	mov.l	cfcode-T(%a6),%d1	# disk configuration code (byte 5)
	mov.l	cfadr-T(%a6),%a2	# configuration data address
	mov.l	ioadr-T(%a6),%a0	# controller io address
	mov.l	readr-T(%a6),%a1	# read routine address

# read a block

	jsr	(%a1)			# VMEbug read disk routine

# read complete, restore and return if good io

	movm.l	(%sp)+,&GETREGS
rb10:	bne.b	rb10			# zero flag is set on good io
					# die if not successful
	rts				# otherwise return


