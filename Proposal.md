**A Language for Approximate Computation in FPGA pipelines**

Michael Mara

* What is the goal of the project? What problem are you trying to solve?

To create a simple math language with separate precision annotations (separated in an aspect-oriented programming like sense) that can be lowered into hardware and/or a fast simulator. This would allow significantly easier transfer of traditional compute-heavy floating point code (like those found in matrix-free optimization problems or imaging pipelines/computer vision) to hardware/FPGAs.

* What do you hope to show when you are done? What are your deliverables?

Besides the system itself, ideally show a complicated math function, hardware synthesized with and without precision annotations, the resultant difference in clock-speed/die area, and a measure of end-to-end precision loss.

* Why is it interesting, challenging, or important about the project?

Requires handling float/fix numbers in a structured way, building a fast simulator, a ton of magma primitives for fixed/float ops, learning a ton about hardware, approximate computation, etc.

* What previous work has been performed in this area?
  What resources do you plan on drawing upon?

The most relevant papers in this area are:

[Rigorous Floating-Point Mixed-Precision Tuning](http://soarlab.org/publications/popl2017-cbbsgr.pdf)

[Stochastic Optimization of Floating-Point Programs with Tunable Precision](https://cs.stanford.edu/people/eschkufz/docs/pldi_14.pdf)

[Grater: an approximation workflow for exploiting data-level parallelism in FPGA acceleration](http://cseweb.ucsd.edu/~alotfi/grater-date16.pdf)


Timeline:

March 3: Base language complete, can lower to cpu code, handle fixed/float

March 10: Lower to hardware

March 17: Interesting example, automated optimization using ideas from 
[Stochastic Optimization of Floating-Point Programs with Tunable Precision](https://cs.stanford.edu/people/eschkufz/docs/pldi_14.pdf) and [Grater: an approximation workflow for exploiting data-level parallelism in FPGA acceleration](http://cseweb.ucsd.edu/~alotfi/grater-date16.pdf)


Right before submitting this, I talked with our Professor and our TA, and was presented with a very interesting idea of a super-fast simulator through compilation then STOKE-style superoptimization, and using that to in turn do STOKE-style super optimization on a logic block. That seems totally awesome and potentially a better project, but I didn't have time to consider it more fully before the proposal submission. I'll be thinking of it more this next week.
