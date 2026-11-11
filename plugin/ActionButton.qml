import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
FeedbackButton {
  radius: Math.min(Style.cornerRadius,Style.space(6))
  horizontalPadding: Style.space(9)
  verticalPadding: Style.space(4)
  fontSize: Style.font.bodySmall
  focusable: true
}
