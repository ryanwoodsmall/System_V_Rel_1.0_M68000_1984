#	@(#)turnoff.sh	2.1	
# Enter any new games with mode 100 or, for shell procedures, 544
for i in /usr/games/*
do
	if [ -f "$i" -a -x "$i" ]
	then
		chmod go-x "$i"
	fi
done
chmod go+x /usr/games/fortune
