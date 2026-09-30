using UnityEngine;
using UnityEngine.UI;

namespace Refugee1950
{
    /// <summary>
    /// 타이틀 화면의 "처음부터" / "이어하기" 버튼.
    /// </summary>
    public class TitleMenu : MonoBehaviour
    {
        public string firstScene = "Ch1_Seoul";
        public Button continueButton;

        void Start()
        {
            if (continueButton != null)
                continueButton.interactable = GameManager.Instance != null && GameManager.Instance.HasSave();
        }

        public void OnNewGame() => GameManager.Instance.NewGame(firstScene);

        public void OnContinue() => GameManager.Instance.Continue();

        public void OnQuit()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            Application.Quit();
#endif
        }
    }
}
