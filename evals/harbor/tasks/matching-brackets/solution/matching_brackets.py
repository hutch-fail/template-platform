# Canonical solution adapted from Exercism python track
# exercises/practice/matching-brackets/.meta/example.py


def is_paired(input_string):
    counterparts = {')': '(', '}': '{', ']': '['}

    stack = []
    for char in input_string:
        if char in counterparts.values():
            stack.append(char)
        elif char in counterparts:
            if not stack:
                return False
            if stack.pop() != counterparts[char]:
                return False
    return not stack
