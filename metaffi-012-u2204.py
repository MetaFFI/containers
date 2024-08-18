import subprocess

commands = [
    "docker build -f metaffi-012-u2204.dockerfile --progress=plain -t tscs/metaffi-012-u2204:0.0.2 .",
    "docker push tscs/metaffi-012-u2204:0.0.2",
    "docker tag tscs/metaffi-012-u2204:0.0.2 tscs/metaffi-012-u2204:latest",
    "docker push tscs/metaffi-012-u2204:latest"
]

for command in commands:
    print(f"+++ Running command: {str(command)}")
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    # Realtime output
    while True:
        if process.stdout is None:
            raise Exception("stdout is None")

        readdata = process.stdout.read()
        if readdata is None:
            continue

        output = readdata.decode('utf-8')
        if output == '' and process.poll() is not None:
            break
        if output:
            print(output.strip())
    rc = process.poll()

    # If a command fails, the process fails
    if rc != 0:
        print(f"Command failed with return code: {rc}")
        break