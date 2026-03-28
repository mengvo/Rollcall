// PeopleListView.swift

import SwiftUI

struct PeopleListView: View {
    let people: [IdentifiedPerson]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(people) { person in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(String(person.name.prefix(1)))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            Text(person.name)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("\(Int(person.confidence * 100))%")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
