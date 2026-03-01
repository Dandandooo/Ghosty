import sys
import time

def main() -> int:
    text = " ".join(sys.argv[1:]).strip()
    time.sleep(1)
    # GhostyApp expects the response on stdout
    print(f'Bro actually said: "{text}"\n')
    for word in "THIS IS GHOSTY FOR REAL".split():
        time.sleep(0.25)
        print(word, end=' ', flush=True)
    print('\n')
    for i in range(10):
        time.sleep(0.1)
        print(i, end=' ', flush=True)
    print('\n')
    return 0

if __name__ == "__main__":
    sys.exit(main())
