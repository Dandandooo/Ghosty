import SwiftUI

// MARK: – GitHub Invertocat Mark

/// The GitHub Invertocat logo drawn as a SwiftUI Shape (24×24 design space).
struct GitHubMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        let dx = (rect.width - 24 * s) / 2
        let dy = (rect.height - 24 * s) / 2

        var p = Path()
        p.move(to: pt(12, 0.297, s, dx, dy))
        p.addCurve(to: pt(0, 12.297, s, dx, dy), control1: pt(5.37, 0.297, s, dx, dy), control2: pt(0, 5.67, s, dx, dy))
        p.addCurve(to: pt(8.205, 23.682, s, dx, dy), control1: pt(0, 17.6, s, dx, dy), control2: pt(3.438, 22.097, s, dx, dy))
        p.addCurve(to: pt(9.025, 23.105, s, dx, dy), control1: pt(8.805, 23.795, s, dx, dy), control2: pt(9.025, 23.424, s, dx, dy))
        p.addCurve(to: pt(9.01, 21.065, s, dx, dy), control1: pt(9.025, 22.82, s, dx, dy), control2: pt(9.015, 22.065, s, dx, dy))
        p.addCurve(to: pt(4.968, 19.455, s, dx, dy), control1: pt(5.672, 21.789, s, dx, dy), control2: pt(4.968, 19.455, s, dx, dy))
        p.addCurve(to: pt(3.633, 17.7, s, dx, dy), control1: pt(4.422, 18.07, s, dx, dy), control2: pt(3.633, 17.7, s, dx, dy))
        p.addCurve(to: pt(3.717, 16.971, s, dx, dy), control1: pt(2.546, 16.956, s, dx, dy), control2: pt(3.717, 16.971, s, dx, dy))
        p.addCurve(to: pt(5.555, 18.207, s, dx, dy), control1: pt(4.922, 17.055, s, dx, dy), control2: pt(5.555, 18.207, s, dx, dy))
        p.addCurve(to: pt(9.05, 19.205, s, dx, dy), control1: pt(6.625, 20.042, s, dx, dy), control2: pt(8.364, 19.512, s, dx, dy))
        p.addCurve(to: pt(9.81, 17.6, s, dx, dy), control1: pt(9.158, 18.429, s, dx, dy), control2: pt(9.467, 17.9, s, dx, dy))
        p.addCurve(to: pt(4.344, 11.67, s, dx, dy), control1: pt(7.145, 17.3, s, dx, dy), control2: pt(4.344, 16.268, s, dx, dy))
        p.addCurve(to: pt(5.579, 8.45, s, dx, dy), control1: pt(4.344, 10.36, s, dx, dy), control2: pt(4.809, 9.29, s, dx, dy))
        p.addCurve(to: pt(5.684, 5.274, s, dx, dy), control1: pt(5.444, 8.147, s, dx, dy), control2: pt(5.039, 6.927, s, dx, dy))
        p.addCurve(to: pt(8.984, 6.504, s, dx, dy), control1: pt(5.684, 5.274, s, dx, dy), control2: pt(6.689, 4.952, s, dx, dy))
        p.addCurve(to: pt(11.984, 6.099, s, dx, dy), control1: pt(9.944, 6.237, s, dx, dy), control2: pt(10.964, 6.105, s, dx, dy))
        p.addCurve(to: pt(14.984, 6.504, s, dx, dy), control1: pt(13.004, 6.105, s, dx, dy), control2: pt(14.024, 6.237, s, dx, dy))
        p.addCurve(to: pt(18.269, 5.274, s, dx, dy), control1: pt(17.264, 4.952, s, dx, dy), control2: pt(18.269, 5.274, s, dx, dy))
        p.addCurve(to: pt(18.389, 8.45, s, dx, dy), control1: pt(18.914, 6.927, s, dx, dy), control2: pt(18.509, 8.147, s, dx, dy))
        p.addCurve(to: pt(19.619, 11.67, s, dx, dy), control1: pt(19.154, 9.29, s, dx, dy), control2: pt(19.619, 10.36, s, dx, dy))
        p.addCurve(to: pt(14.144, 17.59, s, dx, dy), control1: pt(19.619, 16.28, s, dx, dy), control2: pt(16.814, 17.295, s, dx, dy))
        p.addCurve(to: pt(14.954, 19.81, s, dx, dy), control1: pt(14.564, 17.95, s, dx, dy), control2: pt(14.954, 18.686, s, dx, dy))
        p.addCurve(to: pt(14.939, 23.096, s, dx, dy), control1: pt(14.954, 21.416, s, dx, dy), control2: pt(14.939, 22.706, s, dx, dy))
        p.addCurve(to: pt(15.764, 23.666, s, dx, dy), control1: pt(14.939, 23.411, s, dx, dy), control2: pt(15.149, 23.786, s, dx, dy))
        p.addCurve(to: pt(24, 12.297, s, dx, dy), control1: pt(20.565, 22.092, s, dx, dy), control2: pt(24, 17.592, s, dx, dy))
        p.addCurve(to: pt(12, 0.297, s, dx, dy), control1: pt(24, 5.67, s, dx, dy), control2: pt(18.627, 0.297, s, dx, dy))
        return p
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
        CGPoint(x: x * s + dx, y: y * s + dy)
    }
}

// MARK: – Notion Logo View

/// A simplified Notion logo: serif "N" inside a rounded rectangle, matching the
/// distinctive Notion brand mark at small sizes.
struct NotionMarkView: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .strokeBorder(lineWidth: size * 0.07)
            Text("N")
                .font(.system(size: size * 0.6, weight: .bold, design: .serif))
                .baselineOffset(size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

// MARK: – Playwright Logo View

/// A simplified Playwright mark: the green "PW" letters that forms the
/// recognisable Playwright brand. Falls back to the theatre-masks SF Symbol
/// aesthetic but with correct green tinting.
struct PlaywrightMarkView: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
            Text("PW")
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .foregroundStyle(.green)
        }
        .frame(width: size, height: size)
    }
}

// MARK: – Context7 Logo View

/// Context7 brand mark — a bold "C7" monogram.
struct Context7MarkView: View {
    var size: CGFloat = 22

    var body: some View {
        Text("C7")
            .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
    }
}
