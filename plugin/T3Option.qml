import QtQuick
import "T3Model.js" as T3

ChoiceButton {
  required property var option
  label: option.label
  description: T3.optionDescription(option)
}
