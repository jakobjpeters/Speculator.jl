
module TestJET

import Speculator
using JET: report_package

report_package(Speculator; target_modules = [Speculator])

end # module
