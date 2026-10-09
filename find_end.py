with open('lib/features/chat/pantallas/chats_pantalla.dart', 'r') as f:
    content = f.read()

idx = content.find('return RefreshIndicator(')
print('Found at:', idx)

# Find end by counting braces
brace_count = 0
in_string = False
escape = False
end = -1
for i in range(idx, len(content)):
    c = content[i]
    if not in_string:
        if c == '{':
            brace_count += 1
        elif c == '}':
            brace_count -= 1
            if brace_count == 0:
                print(f'End at: {i+1}')
                break
        elif c == '"':
            in_string = True
        elif c == '\\' and not escape:
            escape = True
        elif c == '"' and not escape:
            in_string = False
            escape = False
        else:
            escape = False
    if brace_count == 0 and i > 0:
        print('Found end at:', i+1)
        break
else:
    print('Not found end')

if end > 0:
    print('Old content length:', end - content.find('return RefreshIndicator('))
    # Show first 200 chars
    old = content[content.find('return RefreshIndicator('):end]
    print(repr(old[:300]))