module mycpu_top(
    input  [ 5:0] int,      // high active

    input         aclk,
    input         aresetn,  // low active

    input  [ 3:0] arid
)