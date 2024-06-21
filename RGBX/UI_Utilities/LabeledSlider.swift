import SwiftUI

struct LabeledSlider: View {
    let name: String
    @Binding var value: Float
    let min: Float
    let max: Float
    let step: Float?
    
    init(name: String, value: Binding<Float>, min: Float = 0.0, max: Float = 1.0, step: Float? = nil) {
        self.name = name
        self._value = value
        self.min = min
        self.max = max
        self.step = step
    }
    
    var body: some View {
        HStack {
            if step == nil {
                Slider(value: $value, in: min...max) {
                    Text(name)
                }
            } else {
                Slider(value: $value, in: min...max, step: step!) {
                    Text(name)
                }
            }
            Text("\(value)")
        }
    }
}
