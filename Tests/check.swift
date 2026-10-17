import Foundation

if let problem = ScoutMath.selfCheck() {
    fputs(problem + "\n", stderr)
    exit(1)
}
print("ok")
