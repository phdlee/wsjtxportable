CC = gcc
#CC = clang-3.5
FC = gfortran

CFLAGS= -I/usr/include -Wall -Wno-missing-braces -O3 -ffast-math
LDFLAGS = -L/usr/lib
FFLAGS =  -O2 -Wall -Wno-conversion
LIBS = -lfftw3f -lm

# Default rules
%.o: %.c $(DEPS)
	${CC} ${CFLAGS} -c $<
%.o: %.f
	${FC} ${FFLAGS} -c $<
%.o: %.F
	${FC} ${FFLAGS} -c $<
%.o: %.f90
	${FC} ${FFLAGS} -c $<
%.o: %.F90
	${FC} ${FFLAGS} -c $<

all:    wsprd wsprsim wsprd_exp

DEPS =  wsprsim_utils.h wsprd_utils.h fano.h jelinek.h nhash.h
OBJS1 = wsprd.o wsprsim_utils.o wsprd_utils.o tab.o fano.o jelinek.o nhash.o
wsprd: $(OBJS1)
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) $(LIBS)

OBJS2 = wsprsim.o wsprsim_utils.o wsprd_utils.o tab.o fano.o nhash.o 
wsprsim: $(OBJS2) 
	$(CC) -o $@ $^ $(CFLAGS) $(LDFLAGS) $(LIBS)

clean:
	rm *.o wsprd wsprsim
