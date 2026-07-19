# System Model and Parameter Identification

## Rotational equation of motion

\[
J\alpha = T_A - c\omega - T_f
\]

where:

- \(J\) is the rotational inertia,
- \(c\) is the viscous damping coefficient,
- \(T_f\) is the friction torque,
- \(T_A\) is the applied motor torque,
- \(\omega\) is angular velocity,
- \(\alpha\) is angular acceleration.

The experimental parameter-identification equations were:

\[
J=\frac{T_A}{\alpha_1-\alpha_3}
\]

\[
c=-J\frac{\alpha_2-\alpha_3}{\omega_2}
\]

\[
T_f=-J\alpha_3
\]

The identified values were:

| Parameter | Value |
|---|---:|
| Rotational inertia, \(J\) | 0.006972 kg m² |
| Viscous damping, \(c\) | 0.002989 N m s |
| Friction torque, \(T_f\) | 0.0357 N m |

## Plant model

\[
G(s)=\frac{1}{Js^2+cs}
\]

## PD controller

\[
C(s)=K_p+K_ds
\]

## Closed-loop transfer function

\[
T(s)=\frac{C(s)G(s)}{1+C(s)G(s)}
\]

Therefore:

\[
T(s)=\frac{K_p+K_ds}{Js^2+(c+K_d)s+K_p}
\]

Substituting the identified plant parameters:

\[
T(s)=\frac{K_p+K_ds}
{0.006972s^2+(0.002989+K_d)s+K_p}
\]
