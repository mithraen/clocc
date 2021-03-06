      SUBROUTINE DIVP(XXXX,YYYY,ZZZZ,IERR)
C
C THIS SUBROUTINE PERFORMS DIVISION  OF COMPLEX NUMBERS:
C ZZZZ = XXXX/YYYY
C
C ON INPUT:
C
C XXXX  IS AN ARRAY OF LENGTH TWO REPRESENTING THE FIRST COMPLEX
C       NUMBER, WHERE XXXX(1) = REAL PART OF XXXX AND XXXX(2) =
C       IMAGINARY PART OF XXXX.
C
C YYYY  IS AN ARRAY OF LENGTH TWO REPRESENTING THE SECOND COMPLEX
C       NUMBER, WHERE YYYY(1) = REAL PART OF YYYY AND YYYY(2) =
C       IMAGINARY PART OF YYYY.
C
C ON OUTPUT:
C
C ZZZZ  IS AN ARRAY OF LENGTH TWO REPRESENTING THE RESULT OF
C       THE DIVISION, ZZZZ = XXXX/YYYY, WHERE ZZZZ(1) =
C       REAL PART OF ZZZZ AND ZZZZ(2) = IMAGINARY PART OF ZZZZ.
C
C IERR =
C  1   IF DIVISION WOULD HAVE CAUSED OVERFLOW.  IN THIS CASE, THE
C      APPROPRIATE PARTS OF ZZZZ ARE SET EQUAL TO THE LARGEST
C      FLOATING POINT NUMBER, AS GIVEN BY FUNCTION  D1MACH .
C
C  0   IF DIVISION DOES NOT CAUSE OVERFLOW.
C
C DECLARATION OF INPUT
      DOUBLE PRECISION XXXX,YYYY
      DIMENSION XXXX(2),YYYY(2)
C
C DECLARATION OF OUTPUT
      INTEGER IERR
      DOUBLE PRECISION ZZZZ
      DIMENSION ZZZZ(2)
C
C DECLARATION OF VARIABLES
      DOUBLE PRECISION DENOM,XNUM,D1MACH
C
      IERR = 0
      DENOM = YYYY(1)*YYYY(1) + YYYY(2)*YYYY(2)
      XNUM    =   XXXX(1)*YYYY(1) + XXXX(2)*YYYY(2)
      IF (ABS(DENOM) .GE. 1.0  .OR.  ( ABS(DENOM) .LT. 1.0   .AND.
     $ ABS(XNUM)/D1MACH(2) .LT. ABS(DENOM) ) ) THEN
            ZZZZ(1) = XNUM/DENOM
          ELSE
            ZZZZ(1) = D1MACH(2)
            IERR =1
          END IF
      XNUM    =   XXXX(2)*YYYY(1) - XXXX(1)*YYYY(2)
      IF (ABS(DENOM) .GE. 1.0  .OR.  ( ABS(DENOM) .LT. 1.0   .AND.
     $ ABS(XNUM)/D1MACH(2) .LT. ABS(DENOM) ) ) THEN
            ZZZZ(2) = XNUM/DENOM
          ELSE
            ZZZZ(2) = D1MACH(2)
            IERR =1
          END IF
      RETURN
      END
