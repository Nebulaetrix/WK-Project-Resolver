using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEditor.PackageManager;
using UnityEditor.PackageManager.Requests;
using UnityEngine.SceneManagement;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.UI;
using System.IO;

public class AutoProjectRepair
{
    static AddRequest[] requests;

    [MenuItem("Tools/Fix Project")]
    static void InstallPackages()
    {
        requests = new AddRequest[]
        {
            Client.Add("https://github.com/Unity-Technologies/AssetBundles-Browser.git"),
            Client.Add("com.unity.burst@1.8.27"),
            Client.Add("com.unity.formats.fbx@4.2.0"),
            Client.Add("com.unity.inputsystem@1.19.0"),
            Client.Add("com.unity.ugui@1.0.0")
            //Client.Add("com.unity.textmeshpro@3.0.6")
        };

        EditorApplication.update += WaitForPackages;
    }

    static void WaitForPackages()
    {
        foreach (var r in requests)
        {
            if (!r.IsCompleted)
                return;
        }

        EditorApplication.update -= WaitForPackages;

        foreach (var r in requests)
        {
            if (r.Status == StatusCode.Success)
                Debug.Log("Installed: " + r.Result.packageId);
            else if (r.Status >= StatusCode.Failure)
                Debug.LogError(r.Error.message);
        }

        Debug.Log("All packages processed.");

        ContinueRepair();
    }
    
    static void ContinueRepair()
    {
        DeleteInputDLLs();
        FixAllScenes();

        AssetDatabase.SaveAssets();
    }

    static void DeleteInputDLLs()
    {
        string root = Application.dataPath;

        var files = Directory.GetFiles(root, "Unity.Input*.dll", SearchOption.AllDirectories);

        foreach (var file in files)
        {
            File.Delete(file);
            Debug.Log("Deleted " + file);
        }
    }

    static void FixAllScenes()
    {
        string[] scenes = AssetDatabase.FindAssets("t:Scene");

        foreach (string guid in scenes)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);

            if (!path.StartsWith("Assets/"))
                continue;
            
            Scene scene = EditorSceneManager.OpenScene(path);

            Debug.Log("Processing scene: " + path);

            //RemoveBrokenScripts();
            FixInputManager();
            FixEventSystem();
            DisableCRT();

            EditorSceneManager.SaveScene(scene);
        }
    }

    static void RemoveBrokenScripts()
    {
        GameObject[] objects = Object.FindObjectsOfType<GameObject>(true);

        foreach (GameObject obj in objects)
        {
            if (GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(obj) > 0)
            {
                GameObjectUtility.RemoveMonoBehavioursWithMissingScript(obj);
                Debug.Log("Removed missing scripts from " + obj.name);
            }
        }
    }

    static void FixInputManager()
    {
        GameObject obj = GameObject.Find("InputManager");

        if (!obj) return;

        if (!obj.GetComponent<PlayerInput>())
        {
            var input = obj.AddComponent<PlayerInput>();

            var actions = FindInputActions();

            if (actions)
                input.actions = actions;

            Debug.Log("PlayerInput added to InputManager.");
        }
    }

    static void FixEventSystem()
    {
        GameObject obj = GameObject.Find("EventSystem_Default");

        if (!obj) return;

        if (!obj.GetComponent<InputSystemUIInputModule>())
        {
            var module = obj.AddComponent<InputSystemUIInputModule>();

            var actions = FindInputActions();

            if (actions)
                module.actionsAsset = actions;

            Debug.Log("UI Input Module added to EventSystem.");
        }
    }

    static InputActionAsset FindInputActions()
    {
        string[] assets = AssetDatabase.FindAssets("t:InputActionAsset");

        if (assets.Length == 0)
            return null;

        string path = AssetDatabase.GUIDToAssetPath(assets[0]);

        return AssetDatabase.LoadAssetAtPath<InputActionAsset>(path);
    }

    static void DisableCRT()
    {
        GameObject[] objects = Object.FindObjectsOfType<GameObject>(true);

        foreach (GameObject obj in objects)
        {
            var behaviours = obj.GetComponents<MonoBehaviour>();

            foreach (var comp in behaviours)
            {
                if (comp && comp.GetType().Name.Contains("CRT"))
                {
                    comp.enabled = false;
                    Debug.Log("Disabled CRT component on " + obj.name);
                }
            }
        }
    }
}
