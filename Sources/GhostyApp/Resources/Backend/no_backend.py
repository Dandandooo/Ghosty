import sys
import time

def main() -> int:
    text = " ".join(sys.argv[1:]).strip()
    time.sleep(1)
    # GhostyApp expects the response on stdout
    print(f'Bro actually said: "{text}"')
    return 0

if __name__ == "__main__":
    sys.exit(main())
