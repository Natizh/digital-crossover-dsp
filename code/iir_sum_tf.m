function [Bsum, Asum] = iir_sum_tf(iir)
%IIR_SUM_TF Return the equivalent transfer function of Hlp(z) + Hhp(z).

Bsum = conv(iir.bLP, iir.aHP) + conv(iir.bHP, iir.aLP);
Asum = conv(iir.aLP, iir.aHP);

end
